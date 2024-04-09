import Foundation
import AVKit
import AVFoundation
import CoreMedia
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit

private func sampleBufferFromPixelBuffer(pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
    var maybeFormat: CMVideoFormatDescription?
    let status = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &maybeFormat)
    if status != noErr {
        return nil
    }
    guard let format = maybeFormat else {
        return nil
    }

    var timingInfo = CMSampleTimingInfo(
        duration: CMTimeMake(value: 1, timescale: 30),
        presentationTimeStamp: CMTimeMake(value: 0, timescale: 30),
        decodeTimeStamp: CMTimeMake(value: 0, timescale: 30)
    )

    var maybeSampleBuffer: CMSampleBuffer?
    let bufferStatus = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescription: format, sampleTiming: &timingInfo, sampleBufferOut: &maybeSampleBuffer)

    if (bufferStatus != noErr) {
        return nil
    }
    guard let sampleBuffer = maybeSampleBuffer else {
        return nil
    }

    let attachments: NSArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true)! as NSArray
    let dict: NSMutableDictionary = attachments[0] as! NSMutableDictionary
    dict[kCMSampleAttachmentKey_DisplayImmediately as NSString] = true as NSNumber

    return sampleBuffer
}

final class PrivateCallPictureInPictureView: UIView {
    private final class SampleBufferView: UIView {
        override static var layerClass: AnyClass {
            return AVSampleBufferDisplayLayer.self
        }
    }

    private let videoContainerView: UIView
    private let sampleBufferView: SampleBufferView
    
    private var videoMetrics: VideoContainerView.VideoMetrics?
    private var videoDisposable: Disposable?
    
    var isRenderingEnabled: Bool = false {
        didSet {
            if self.isRenderingEnabled != oldValue {
                self.updateContents()
            }
        }
    }
    var video: VideoSource? {
        didSet {
            if self.video !== oldValue {
                self.videoDisposable?.dispose()
                if let video = self.video {
                    self.videoDisposable = video.addOnUpdated({ [weak self] in
                        guard let self else {
                            return
                        }
                        if self.isRenderingEnabled {
                            self.updateContents()
                        }
                    })
                }
            }
        }
    }
    
    override static var layerClass: AnyClass {
        return AVSampleBufferDisplayLayer.self
    }
    
    override init(frame: CGRect) {

        self.videoContainerView = UIView()
        self.sampleBufferView = SampleBufferView()
        
        super.init(frame: frame)

        self.backgroundColor = .black
        
        self.videoContainerView.addSubview(self.sampleBufferView)
        self.addSubview(self.videoContainerView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateContents() {
        guard let video = self.video, let currentOutput = video.currentOutput else {
            return
        }
        guard let pixelBuffer = currentOutput.dataBuffer.pixelBuffer else {
            return
        }
        let videoMetrics = VideoContainerView.VideoMetrics(resolution: currentOutput.resolution, rotationAngle: currentOutput.rotationAngle, followsDeviceOrientation: currentOutput.followsDeviceOrientation, sourceId: currentOutput.sourceId)
        if self.videoMetrics != videoMetrics {
            self.videoMetrics = videoMetrics
            self.setNeedsLayout()
        }
        
        if let sampleBuffer = sampleBufferFromPixelBuffer(pixelBuffer: pixelBuffer) {
            (self.sampleBufferView.layer as? AVSampleBufferDisplayLayer)?.enqueue(sampleBuffer)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        if size.width.isZero || size.height.isZero {
            return
        }

        let animationDuration = CATransaction.animationDuration()
        let timingFunction = CATransaction.animationTimingFunction()
        
        let mappedTransition: Transition
        if self.sampleBufferView.bounds.isEmpty {
            mappedTransition = .immediate
        } else if animationDuration > 0.0 && !CATransaction.disableActions() {
            let mappedCurve: Transition.Animation.Curve
            if let timingFunction {
                var controlPoint0: [Float] = [0.0, 0.0]
                var controlPoint1: [Float] = [0.0, 0.0]
                timingFunction.getControlPoint(at: 1, values: &controlPoint0)
                timingFunction.getControlPoint(at: 2, values: &controlPoint1)
                mappedCurve = .custom(controlPoint0[0], controlPoint0[1], controlPoint1[0], controlPoint1[1])
            } else if animationDuration >= 0.5 {
                mappedCurve = .spring
            } else {
                mappedCurve = .easeInOut
            }
            mappedTransition = Transition(animation: .curve(
                duration: animationDuration,
                curve: mappedCurve
            ))
        } else {
            mappedTransition = .immediate
        }
        
        if let videoMetrics = self.videoMetrics {
            let resolvedRotationAngle = resolveVideoRotationAngle(angle: videoMetrics.rotationAngle, followsDeviceOrientation: videoMetrics.followsDeviceOrientation, interfaceOrientation: UIApplication.shared.statusBarOrientation)
            
            var rotatedResolution = videoMetrics.resolution
            var videoIsRotated = false
            if resolvedRotationAngle == Float.pi * 0.5 || resolvedRotationAngle == Float.pi * 3.0 / 2.0 {
                rotatedResolution = CGSize(width: rotatedResolution.height, height: rotatedResolution.width)
                videoIsRotated = true
            }
            
            var videoSize = rotatedResolution.aspectFitted(size)
            let boundingAspectRatio = size.width / size.height
            let videoAspectRatio = videoSize.width / videoSize.height
            let isFillingBounds = abs(boundingAspectRatio - videoAspectRatio) < 0.15
            if isFillingBounds {
                videoSize = rotatedResolution.aspectFilled(size)
            }
            
            let rotatedBoundingSize = videoIsRotated ? CGSize(width: size.height, height: size.width) : size
            let rotatedVideoSize = videoIsRotated ? CGSize(width: videoSize.height, height: videoSize.width) : videoSize
            
            let videoFrame = rotatedVideoSize.centered(around: CGPoint(x: rotatedBoundingSize.width * 0.5, y: rotatedBoundingSize.height * 0.5))
            
            let apply: (Transition) -> Void = { transition in
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.videoContainerView.transform = CGAffineTransformMakeRotation(CGFloat(resolvedRotationAngle))
                CATransaction.commit()

                transition.setBounds(view: self.videoContainerView, bounds: CGRect(origin: CGPoint(), size: rotatedBoundingSize))
                transition.setPosition(view: self.videoContainerView, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))

                transition.setBounds(view: self.sampleBufferView, bounds: CGRect(origin: CGPoint(), size: videoFrame.size))
                transition.setPosition(view: self.sampleBufferView, position: videoFrame.center)

                if let sublayers = self.sampleBufferView.layer.sublayers {
                    if sublayers.count > 1, !sublayers[0].bounds.isEmpty {
                        transition.setBounds(layer: sublayers[0], bounds: CGRect(origin: CGPoint(), size: videoFrame.size))
                        transition.setPosition(layer: sublayers[0], position: CGPoint(x: videoFrame.width * 0.5, y: videoFrame.height * 0.5))
                    }
                }
            }
            
            if !mappedTransition.animation.isImmediate {
                apply(mappedTransition)
            } else {
                UIView.performWithoutAnimation {
                    apply(mappedTransition)
                }
            }
        }
    }
}
