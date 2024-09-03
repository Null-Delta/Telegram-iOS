import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import BundleIconComponent
import MetalEngine
import CallScreen
import TelegramCore
import AccountContext
import SwiftSignalKit
import DirectMediaImageCache
import FastBlur

private func blurredAvatarImage(_ dataImage: UIImage) -> UIImage? {
    let imageContextSize = CGSize(width: 64.0, height: 64.0)
    if let imageContext = DrawingContext(size: imageContextSize, scale: 1.0, clear: true) {
        imageContext.withFlippedContext { c in
            if let cgImage = dataImage.cgImage {
                c.draw(cgImage, in: CGRect(origin: CGPoint(), size: imageContextSize))
            }
        }
        
        telegramFastBlurMore(Int32(imageContext.size.width * imageContext.scale), Int32(imageContext.size.height * imageContext.scale), Int32(imageContext.bytesPerRow), imageContext.bytes)
        
        return imageContext.generateImage()
    } else {
        return nil
    }
}

private let activityBorderImage: UIImage = {
    return generateStretchableFilledCircleImage(diameter: 20.0, color: nil, strokeColor: .white, strokeWidth: 2.0)!.withRenderingMode(.alwaysTemplate)
}()

final class VideoChatParticipantVideoComponent: Component {
    let call: PresentationGroupCall
    let participant: GroupCallParticipantsContext.Participant
    let isPresentation: Bool
    let isSpeaking: Bool
    let isExpanded: Bool
    let bottomInset: CGFloat
    let action: (() -> Void)?
    
    init(
        call: PresentationGroupCall,
        participant: GroupCallParticipantsContext.Participant,
        isPresentation: Bool,
        isSpeaking: Bool,
        isExpanded: Bool,
        bottomInset: CGFloat,
        action: (() -> Void)?
    ) {
        self.call = call
        self.participant = participant
        self.isPresentation = isPresentation
        self.isSpeaking = isSpeaking
        self.isExpanded = isExpanded
        self.bottomInset = bottomInset
        self.action = action
    }
    
    static func ==(lhs: VideoChatParticipantVideoComponent, rhs: VideoChatParticipantVideoComponent) -> Bool {
        if lhs.participant != rhs.participant {
            return false
        }
        if lhs.isPresentation != rhs.isPresentation {
            return false
        }
        if lhs.isSpeaking != rhs.isSpeaking {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        return true
    }
    
    private struct VideoSpec: Equatable {
        var resolution: CGSize
        var rotationAngle: Float
        
        init(resolution: CGSize, rotationAngle: Float) {
            self.resolution = resolution
            self.rotationAngle = rotationAngle
        }
    }
    
    final class View: HighlightTrackingButton {
        private var component: VideoChatParticipantVideoComponent?
        private weak var componentState: EmptyComponentState?
        private var isUpdating: Bool = false
        private var previousSize: CGSize?
        
        private let muteStatus = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        
        private var blurredAvatarDisposable: Disposable?
        private var blurredAvatarView: UIImageView?
        
        private var videoSource: AdaptedCallVideoSource?
        private var videoDisposable: Disposable?
        private var videoBackgroundLayer: SimpleLayer?
        private var videoLayer: PrivateCallVideoLayer?
        private var videoSpec: VideoSpec?
        
        private var activityBorderView: UIImageView?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            //TODO:release optimize
            self.clipsToBounds = true
            self.layer.cornerRadius = 10.0
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.videoDisposable?.dispose()
            self.blurredAvatarDisposable?.dispose()
        }
        
        @objc private func pressed() {
            guard let component = self.component, let action = component.action else {
                return
            }
            action()
        }
        
        func update(component: VideoChatParticipantVideoComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.componentState = state
            
            let nameColor = component.participant.peer.nameColor ?? .blue
            let nameColors = component.call.accountContext.peerNameColors.get(nameColor, dark: true)
            self.backgroundColor = nameColors.main.withMultiplied(hue: 1.0, saturation: 1.0, brightness: 0.4)
            
            if let smallProfileImage = component.participant.peer.smallProfileImage {
                let blurredAvatarView: UIImageView
                if let current = self.blurredAvatarView {
                    blurredAvatarView = current
                    
                    transition.setFrame(view: blurredAvatarView, frame: CGRect(origin: CGPoint(), size: availableSize))
                } else {
                    blurredAvatarView = UIImageView()
                    blurredAvatarView.contentMode = .scaleAspectFill
                    self.blurredAvatarView = blurredAvatarView
                    self.insertSubview(blurredAvatarView, at: 0)
                    
                    blurredAvatarView.frame = CGRect(origin: CGPoint(), size: availableSize)
                }
                
                if self.blurredAvatarDisposable == nil {
                    //TODO:release synchronous
                    if let imageCache = component.call.accountContext.imageCache as? DirectMediaImageCache, let peerReference = PeerReference(component.participant.peer) {
                        if let result = imageCache.getAvatarImage(peer: peerReference, resource: MediaResourceReference.avatar(peer: peerReference, resource: smallProfileImage.resource), immediateThumbnail: component.participant.peer.profileImageRepresentations.first?.immediateThumbnailData, size: 64, synchronous: false) {
                            if let image = result.image {
                                blurredAvatarView.image = blurredAvatarImage(image)
                            }
                            if let loadSignal = result.loadSignal {
                                self.blurredAvatarDisposable = (loadSignal
                                |> deliverOnMainQueue).startStrict(next: { [weak self] image in
                                    guard let self else {
                                        return
                                    }
                                    if let image {
                                        self.blurredAvatarView?.image = blurredAvatarImage(image)
                                    } else {
                                        self.blurredAvatarView?.image = nil
                                    }
                                })
                            }
                        }
                    }
                }
            } else {
                if let blurredAvatarView = self.blurredAvatarView {
                    self.blurredAvatarView = nil
                    blurredAvatarView.removeFromSuperview()
                }
                if let blurredAvatarDisposable = self.blurredAvatarDisposable {
                    self.blurredAvatarDisposable = nil
                    blurredAvatarDisposable.dispose()
                }
            }
            
            let muteStatusSize = self.muteStatus.update(
                transition: transition,
                component: AnyComponent(VideoChatMuteIconComponent(
                    color: .white,
                    isFilled: true,
                    isMuted: component.participant.muteState != nil
                )),
                environment: {},
                containerSize: CGSize(width: 36.0, height: 36.0)
            )
            let muteStatusFrame: CGRect
            if component.isExpanded {
                muteStatusFrame = CGRect(origin: CGPoint(x: 5.0, y: availableSize.height - component.bottomInset + 1.0 - muteStatusSize.height), size: muteStatusSize)
            } else {
                muteStatusFrame = CGRect(origin: CGPoint(x: 1.0, y: availableSize.height - component.bottomInset + 3.0 - muteStatusSize.height), size: muteStatusSize)
            }
            if let muteStatusView = self.muteStatus.view {
                if muteStatusView.superview == nil {
                    self.addSubview(muteStatusView)
                }
                transition.setPosition(view: muteStatusView, position: muteStatusFrame.center)
                transition.setBounds(view: muteStatusView, bounds: CGRect(origin: CGPoint(), size: muteStatusFrame.size))
                transition.setScale(view: muteStatusView, scale: component.isExpanded ? 1.0 : 0.7)
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.participant.peer.debugDisplayTitle, font: Font.semibold(16.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 8.0 * 2.0, height: 100.0)
            )
            let titleFrame: CGRect
            if component.isExpanded {
                titleFrame = CGRect(origin: CGPoint(x: 36.0, y: availableSize.height - component.bottomInset - 8.0 - titleSize.height), size: titleSize)
            } else {
                titleFrame = CGRect(origin: CGPoint(x: 29.0, y: availableSize.height - component.bottomInset - 4.0 - titleSize.height), size: titleSize)
            }
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                transition.setScale(view: titleView, scale: component.isExpanded ? 1.0 : 0.825)
            }
            
            if let videoDescription = component.isPresentation ? component.participant.presentationDescription : component.participant.videoDescription {
                let videoBackgroundLayer: SimpleLayer
                if let current = self.videoBackgroundLayer {
                    videoBackgroundLayer = current
                } else {
                    videoBackgroundLayer = SimpleLayer()
                    videoBackgroundLayer.backgroundColor = UIColor(white: 0.1, alpha: 1.0).cgColor
                    self.videoBackgroundLayer = videoBackgroundLayer
                    if let blurredAvatarView = self.blurredAvatarView {
                        self.layer.insertSublayer(videoBackgroundLayer, above: blurredAvatarView.layer)
                    } else {
                        self.layer.insertSublayer(videoBackgroundLayer, at: 0)
                    }
                    videoBackgroundLayer.isHidden = true
                }
                
                let videoLayer: PrivateCallVideoLayer
                if let current = self.videoLayer {
                    videoLayer = current
                } else {
                    videoLayer = PrivateCallVideoLayer()
                    self.videoLayer = videoLayer
                    self.layer.insertSublayer(videoLayer.blurredLayer, above: videoBackgroundLayer)
                    self.layer.insertSublayer(videoLayer, above: videoLayer.blurredLayer)
                    
                    videoLayer.blurredLayer.opacity = 0.25
                    
                    if let input = (component.call as! PresentationGroupCallImpl).video(endpointId: videoDescription.endpointId) {
                        let videoSource = AdaptedCallVideoSource(videoStreamSignal: input)
                        self.videoSource = videoSource
                        
                        self.videoDisposable?.dispose()
                        self.videoDisposable = videoSource.addOnUpdated { [weak self] in
                            guard let self, let videoSource = self.videoSource, let videoLayer = self.videoLayer else {
                                return
                            }
                            
                            let videoOutput = videoSource.currentOutput
                            videoLayer.video = videoOutput
                            
                            if let videoOutput {
                                let videoSpec = VideoSpec(resolution: videoOutput.resolution, rotationAngle: videoOutput.rotationAngle)
                                if self.videoSpec != videoSpec {
                                    self.videoSpec = videoSpec
                                    if !self.isUpdating {
                                        self.componentState?.updated(transition: .immediate, isLocal: true)
                                    }
                                }
                            } else {
                                if self.videoSpec != nil {
                                    self.videoSpec = nil
                                    if !self.isUpdating {
                                        self.componentState?.updated(transition: .immediate, isLocal: true)
                                    }
                                }
                            }
                            
                            /*var notifyOrientationUpdated = false
                            var notifyIsMirroredUpdated = false
                            
                            if !self.didReportFirstFrame {
                                notifyOrientationUpdated = true
                                notifyIsMirroredUpdated = true
                            }
                            
                            if let currentOutput = videoOutput {
                                let currentAspect: CGFloat
                                if currentOutput.resolution.height > 0.0 {
                                    currentAspect = currentOutput.resolution.width / currentOutput.resolution.height
                                } else {
                                    currentAspect = 1.0
                                }
                                if self.currentAspect != currentAspect {
                                    self.currentAspect = currentAspect
                                    notifyOrientationUpdated = true
                                }
                                
                                let currentOrientation: PresentationCallVideoView.Orientation
                                if currentOutput.followsDeviceOrientation {
                                    currentOrientation = .rotation0
                                } else {
                                    if abs(currentOutput.rotationAngle - 0.0) < .ulpOfOne {
                                        currentOrientation = .rotation0
                                    } else if abs(currentOutput.rotationAngle - Float.pi * 0.5) < .ulpOfOne {
                                        currentOrientation = .rotation90
                                    } else if abs(currentOutput.rotationAngle - Float.pi) < .ulpOfOne {
                                        currentOrientation = .rotation180
                                    } else if abs(currentOutput.rotationAngle - Float.pi * 3.0 / 2.0) < .ulpOfOne {
                                        currentOrientation = .rotation270
                                    } else {
                                        currentOrientation = .rotation0
                                    }
                                }
                                if self.currentOrientation != currentOrientation {
                                    self.currentOrientation = currentOrientation
                                    notifyOrientationUpdated = true
                                }
                                
                                let currentIsMirrored = !currentOutput.mirrorDirection.isEmpty
                                if self.currentIsMirrored != currentIsMirrored {
                                    self.currentIsMirrored = currentIsMirrored
                                    notifyIsMirroredUpdated = true
                                }
                            }
                            
                            if !self.didReportFirstFrame {
                                self.didReportFirstFrame = true
                                self.onFirstFrameReceived?(Float(self.currentAspect))
                            }
                            
                            if notifyOrientationUpdated {
                                self.onOrientationUpdated?(self.currentOrientation, self.currentAspect)
                            }
                            
                            if notifyIsMirroredUpdated {
                                self.onIsMirroredUpdated?(self.currentIsMirrored)
                            }*/
                            
                            
                        }
                    }
                }
                
                transition.setFrame(layer: videoBackgroundLayer, frame: CGRect(origin: CGPoint(), size: availableSize))
                
                if let videoSpec = self.videoSpec {
                    videoBackgroundLayer.isHidden = false
                    
                    var rotatedResolution = videoSpec.resolution
                    var videoIsRotated = false
                    if abs(videoSpec.rotationAngle - Float.pi * 0.5) < .ulpOfOne || abs(videoSpec.rotationAngle - Float.pi * 3.0 / 2.0) < .ulpOfOne {
                        videoIsRotated = true
                    }
                    if videoIsRotated {
                        rotatedResolution = CGSize(width: rotatedResolution.height, height: rotatedResolution.width)
                    }
                    
                    let videoSize = rotatedResolution.aspectFitted(availableSize)
                    let videoFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - videoSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - videoSize.height) * 0.5)), size: videoSize)
                    let blurredVideoSize = rotatedResolution.aspectFilled(availableSize)
                    let blurredVideoFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - blurredVideoSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - blurredVideoSize.height) * 0.5)), size: blurredVideoSize)
                    
                    let videoResolution = rotatedResolution.aspectFitted(CGSize(width: availableSize.width * 3.0, height: availableSize.height * 3.0))
                    
                    var rotatedVideoResolution = videoResolution
                    var rotatedVideoFrame = videoFrame
                    var rotatedBlurredVideoFrame = blurredVideoFrame
                    
                    if videoIsRotated {
                        rotatedVideoResolution = CGSize(width: rotatedVideoResolution.height, height: rotatedVideoResolution.width)
                        rotatedVideoFrame = rotatedVideoFrame.size.centered(around: rotatedVideoFrame.center)
                        rotatedBlurredVideoFrame = rotatedBlurredVideoFrame.size.centered(around: rotatedBlurredVideoFrame.center)
                    }
                    
                    transition.setPosition(layer: videoLayer, position: rotatedVideoFrame.center)
                    transition.setBounds(layer: videoLayer, bounds: CGRect(origin: CGPoint(), size: rotatedVideoFrame.size))
                    transition.setTransform(layer: videoLayer, transform: CATransform3DMakeRotation(CGFloat(videoSpec.rotationAngle), 0.0, 0.0, 1.0))
                    videoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(rotatedVideoResolution.width), height: Int(rotatedVideoResolution.height)), edgeInset: 2)
                    
                    transition.setPosition(layer: videoLayer.blurredLayer, position: rotatedBlurredVideoFrame.center)
                    transition.setBounds(layer: videoLayer.blurredLayer, bounds: CGRect(origin: CGPoint(), size: rotatedBlurredVideoFrame.size))
                    transition.setTransform(layer: videoLayer.blurredLayer, transform: CATransform3DMakeRotation(CGFloat(videoSpec.rotationAngle), 0.0, 0.0, 1.0))
                }
            } else {
                if let videoBackgroundLayer = self.videoBackgroundLayer {
                    self.videoBackgroundLayer = nil
                    videoBackgroundLayer.removeFromSuperlayer()
                }
                if let videoLayer = self.videoLayer {
                    self.videoLayer = nil
                    videoLayer.blurredLayer.removeFromSuperlayer()
                    videoLayer.removeFromSuperlayer()
                }
                self.videoDisposable?.dispose()
                self.videoDisposable = nil
                self.videoSource = nil
                self.videoSpec = nil
            }
            
            if component.isSpeaking && !component.isExpanded {
                let activityBorderView: UIImageView
                if let current = self.activityBorderView {
                    activityBorderView = current
                } else {
                    activityBorderView = UIImageView()
                    self.activityBorderView = activityBorderView
                    self.addSubview(activityBorderView)
                    
                    activityBorderView.image = activityBorderImage
                    activityBorderView.tintColor = UIColor(rgb: 0x33C758)
                    
                    if let previousSize {
                        activityBorderView.frame = CGRect(origin: CGPoint(), size: previousSize)
                    }
                }
            } else if let activityBorderView = self.activityBorderView {
                if !transition.animation.isImmediate {
                    let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                    if activityBorderView.alpha != 0.0 {
                        alphaTransition.setAlpha(view: activityBorderView, alpha: 0.0, completion: { [weak self, weak activityBorderView] completed in
                            guard let self, let component = self.component, let activityBorderView, self.activityBorderView === activityBorderView, completed else {
                                return
                            }
                            if !component.isSpeaking {
                                activityBorderView.removeFromSuperview()
                                self.activityBorderView = nil
                            }
                        })
                    }
                } else {
                    self.activityBorderView = nil
                    activityBorderView.removeFromSuperview()
                }
            }
            
            if let activityBorderView = self.activityBorderView {
                transition.setFrame(view: activityBorderView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            
            self.previousSize = availableSize
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
