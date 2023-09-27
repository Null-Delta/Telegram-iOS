//
//  ContextAnimationInController.swift
//  ContextUI
//
//  Created by Rustam on 25.08.2023.
//

import Foundation
import Display
import UIKit
import AccountContext

public var contextScale: CGFloat = 1

public protocol ContextAnimationInControllerProtocol {
    func animate(with contentNode: ContextContentNode, in controller: ContextControllerNode, source: ContextContentSource)
}

public protocol ContextAnimationOutControllerProtocol {
    func animate(
        in controller: ContextControllerNode,
        source: ContextContentSource,
        result initialResult: ContextMenuActionResult,
        completion: @escaping () -> Void
    )
}

public protocol ContextAnimatorContainer {
    var animationInController: ContextAnimationInControllerProtocol { get }
    var animationOutController: ContextAnimationOutControllerProtocol { get }
}

public class DefaultContextAnimationInController: ContextAnimationInControllerProtocol {
    public func animate(with contentNode: Display.ContextContentNode, in controller: ContextControllerNode, source: ContextContentSource) {
        switch contentNode {
        case .reference:
            let springDuration: Double = 0.42 * contextAnimationDurationFactor
            let springDamping: CGFloat = 104.0
            
            controller.actionsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2 * contextAnimationDurationFactor)
            controller.actionsContainerNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
            
            if let originalProjectedContentViewFrame = controller.originalProjectedContentViewFrame {
                let localSourceFrame = controller.view.convert(originalProjectedContentViewFrame.1, to: controller.scrollNode.view)
                
                let localContentSourceFrame = controller.view.convert(originalProjectedContentViewFrame.1, to: controller.contentContainerNode.view.superview)
                
                controller.actionsContainerNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: localSourceFrame.center.x - controller.actionsContainerNode.position.x, y: localSourceFrame.center.y - controller.actionsContainerNode.position.y)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true)
                let contentContainerOffset = CGPoint(x: localContentSourceFrame.center.x - controller.contentContainerNode.frame.center.x, y: localContentSourceFrame.center.y - controller.contentContainerNode.frame.center.y)
                controller.contentContainerNode.layer.animateSpring(from: NSValue(cgPoint: contentContainerOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true, completion: { [weak controller] _ in
                    controller?.animatedIn = true
                })
            }
            
        case let .extracted(extracted, keepInPlace):
            let springDuration: Double = 0.42 * contextAnimationDurationFactor
            var springDamping: CGFloat = 104.0
            if case let .extracted(source) = controller.source, source.centerVertically {
                springDamping = 124.0
            }
            
            controller.actionsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2 * contextAnimationDurationFactor)
            controller.actionsContainerNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
            
            if let originalProjectedContentViewFrame = controller.originalProjectedContentViewFrame {
                let contentParentNode = extracted
                let localSourceFrame = controller.view.convert(originalProjectedContentViewFrame.1, to: controller.scrollNode.view)
                
                var actionsDuration = springDuration
                var actionsOffset: CGFloat = 0.0
                var contentDuration = springDuration
                if case let .extracted(source) = controller.source, source.centerVertically {
                    actionsOffset = -(originalProjectedContentViewFrame.1.height - originalProjectedContentViewFrame.0.height) * 0.57
                    actionsDuration *= 1.0
                    contentDuration *= 0.9
                }
                
                let localContentSourceFrame: CGRect
                if keepInPlace {
                    localContentSourceFrame = controller.view.convert(originalProjectedContentViewFrame.1, to: controller.contentContainerNode.view.superview)
                } else {
                    localContentSourceFrame = localSourceFrame
                }
                
                controller.actionsContainerNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: localSourceFrame.center.x - controller.actionsContainerNode.position.x, y: localSourceFrame.center.y - controller.actionsContainerNode.position.y + actionsOffset)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: actionsDuration, initialVelocity: 0.0, damping: springDamping, additive: true)
                let contentContainerOffset = CGPoint(x: localContentSourceFrame.center.x - controller.contentContainerNode.frame.center.x - contentParentNode.contentRect.minX, y: localContentSourceFrame.center.y - controller.contentContainerNode.frame.center.y - contentParentNode.contentRect.minY)
                controller.contentContainerNode.layer.animateSpring(from: NSValue(cgPoint: contentContainerOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: contentDuration, initialVelocity: 0.0, damping: springDamping, additive: true, completion: { [weak controller] _ in
                    controller?.clippingNode.view.mask = nil
                    controller?.animatedIn = true
                })
                contentParentNode.applyAbsoluteOffsetSpring?(-contentContainerOffset.y, springDuration, springDamping)
            }
            
            extracted.willUpdateIsExtractedToContextPreview?(true, .animated(duration: 0.2, curve: .easeInOut))
            
        case .controller(let contextController):
            let springDuration: Double = 0.52 * contextAnimationDurationFactor
            let springDamping: CGFloat = 110.0
            
            contextScale = contextController.transform.m11
            
            controller.actionsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2 * contextAnimationDurationFactor)
            controller.actionsContainerNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
            controller.contentContainerNode.allowsGroupOpacity = true
            controller.contentContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2 * contextAnimationDurationFactor, completion: { [weak controller] _ in
                controller?.contentContainerNode.allowsGroupOpacity = false
            })
            
            if let originalProjectedContentViewFrame = controller.originalProjectedContentViewFrame {
                let localSourceFrame = controller.view.convert(CGRect(origin: CGPoint(x: originalProjectedContentViewFrame.1.minX, y: originalProjectedContentViewFrame.1.minY), size: CGSize(width: originalProjectedContentViewFrame.1.width, height: originalProjectedContentViewFrame.1.height)), to: controller.scrollNode.view)
                
                controller.contentContainerNode.layer.animateSpring(from: min(localSourceFrame.width / controller.contentContainerNode.frame.width, localSourceFrame.height / controller.contentContainerNode.frame.height) as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: springDuration, initialVelocity: 0.0, damping: springDamping)
                
                switch controller.source {
                case let .controller(controller):
                    controller.animatedIn()
                default:
                    break
                }
                
                let contentContainerOffset = CGPoint(x: localSourceFrame.center.x - controller.contentContainerNode.frame.center.x, y: localSourceFrame.center.y - controller.contentContainerNode.frame.center.y)
                
                controller.actionsContainerNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: localSourceFrame.center.x - controller.actionsContainerNode.position.x, y: localSourceFrame.center.y - controller.actionsContainerNode.position.y)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true)
                
                controller.contentContainerNode.layer.animateSpring(from: NSValue(cgPoint: contentContainerOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true, completion: { [weak controller] _ in
                    controller?.animatedIn = true
                })
            }
        }
    }
    
    public init() {
        
    }
}

public class DefaultContextAnimationOutController: ContextAnimationOutControllerProtocol {
    private var needAddShapshot: Bool = true

    public func animate(in controller: ContextControllerNode, source: ContextContentSource, result initialResult: ContextMenuActionResult, completion: @escaping () -> Void) {
        
        var transitionDuration: Double = 0.2
        var transitionCurve: ContainedViewLayoutTransitionCurve = .easeInOut
        
        var result = initialResult
        
        let `self` = controller

        
        switch self.source {
        case let .location(source):
            let transitionInfo = source.transitionInfo()
            if transitionInfo == nil {
                result = .dismissWithoutContent
            }
            
            switch result {
            case let .custom(value):
                switch value {
                case let .animated(duration, curve):
                    transitionDuration = duration
                    transitionCurve = curve
                default:
                    break
                }
            default:
                break
            }
            
            self.isUserInteractionEnabled = false
            self.isAnimatingOut = true
            
            self.scrollNode.view.setContentOffset(self.scrollNode.view.contentOffset, animated: false)
                                                
            if !self.dimNode.isHidden {
                self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * contextAnimationDurationFactor, removeOnCompletion: false)
            } else {
                self.withoutBlurDimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * contextAnimationDurationFactor, removeOnCompletion: false)
            }
            
            self.actionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15 * contextAnimationDurationFactor, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.actionsContainerNode.layer.animateScale(from: 1.0, to: 0.1, duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            
            let animateOutToItem: Bool
            switch result {
            case .default, .custom, .justDismiss:
                animateOutToItem = true
            case .dismissWithoutContent:
                animateOutToItem = false
            }
            
            if animateOutToItem, let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                let localSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.scrollNode.view)
                self.actionsContainerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: localSourceFrame.center.x - self.actionsContainerNode.position.x, y: localSourceFrame.center.y - self.actionsContainerNode.position.y), duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false, additive: true)
            }
        case let .reference(source):
            guard let maybeContentNode = self.contentContainerNode.contentNode, case let .reference(referenceView) = maybeContentNode else {
                return
            }
            
            let transitionInfo = source.transitionInfo()
            if transitionInfo == nil {
                result = .dismissWithoutContent
            }
            
            switch result {
            case let .custom(value):
                switch value {
                case let .animated(duration, curve):
                    transitionDuration = duration
                    transitionCurve = curve
                default:
                    break
                }
            default:
                break
            }
            
            self.isUserInteractionEnabled = false
            self.isAnimatingOut = true
            
            self.scrollNode.view.setContentOffset(self.scrollNode.view.contentOffset, animated: false)
            
            if let transitionInfo = transitionInfo, let parentSuperview = referenceView.superview {
                self.originalProjectedContentViewFrame = (convertFrame(referenceView.frame, from: parentSuperview, to: self.view), convertFrame(referenceView.bounds, from: referenceView, to: self.view))
                
                var updatedContentAreaInScreenSpace = transitionInfo.contentAreaInScreenSpace
                updatedContentAreaInScreenSpace.origin.x = 0.0
                updatedContentAreaInScreenSpace.size.width = self.bounds.width
                
                self.clippingNode.layer.animateFrame(from: self.clippingNode.frame, to: updatedContentAreaInScreenSpace, duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
                self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: updatedContentAreaInScreenSpace.minY, duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            }
                                    
            if !self.dimNode.isHidden {
                self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * contextAnimationDurationFactor, removeOnCompletion: false)
            } else {
                self.withoutBlurDimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * contextAnimationDurationFactor, removeOnCompletion: false)
            }
            
            self.actionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15 * contextAnimationDurationFactor, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.actionsContainerNode.layer.animateScale(from: 1.0, to: 0.1, duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            
            let animateOutToItem: Bool
            switch result {
            case .default, .custom, .justDismiss:
                animateOutToItem = true
            case .dismissWithoutContent:
                animateOutToItem = false
            }
            
            if animateOutToItem, let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                let localSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.scrollNode.view)
                self.actionsContainerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: localSourceFrame.center.x - self.actionsContainerNode.position.x, y: localSourceFrame.center.y - self.actionsContainerNode.position.y), duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false, additive: true)
            }
        case let .extracted(source):
            guard let maybeContentNode = self.contentContainerNode.contentNode, case let .extracted(contentParentNode, keepInPlace) = maybeContentNode else {
                return
            }
            
            let putBackInfo = source.putBack()
            
            if putBackInfo == nil {
                result = .dismissWithoutContent
            }
            
            switch result {
            case let .custom(value):
                switch value {
                case let .animated(duration, curve):
                    transitionDuration = duration
                    transitionCurve = curve
                default:
                    break
                }
            default:
                break
            }
            
            self.isUserInteractionEnabled = false
            self.isAnimatingOut = true
            
            self.scrollNode.view.setContentOffset(self.scrollNode.view.contentOffset, animated: false)
            
            var completedEffect = false
            var completedContentNode = false
            var completedActionsNode = false
            
            if let putBackInfo = putBackInfo, let parentSupernode = contentParentNode.supernode {
                self.originalProjectedContentViewFrame = (convertFrame(contentParentNode.frame, from: parentSupernode.view, to: self.view), convertFrame(contentParentNode.contentRect, from: contentParentNode.view, to: self.view))
                
                var updatedContentAreaInScreenSpace = putBackInfo.contentAreaInScreenSpace
                updatedContentAreaInScreenSpace.origin.x = 0.0
                updatedContentAreaInScreenSpace.size.width = self.bounds.width
                
                self.clippingNode.view.mask = putBackInfo.maskView
                let previousFrame = self.clippingNode.frame
                self.clippingNode.position = updatedContentAreaInScreenSpace.center
                self.clippingNode.bounds = CGRect(origin: CGPoint(), size: updatedContentAreaInScreenSpace.size)
                self.clippingNode.layer.animatePosition(from: previousFrame.center, to: updatedContentAreaInScreenSpace.center, duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: true)
                self.clippingNode.layer.animateBounds(from: CGRect(origin: CGPoint(), size: previousFrame.size), to: CGRect(origin: CGPoint(), size: updatedContentAreaInScreenSpace.size), duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: true)
                //self.clippingNode.layer.animateFrame(from: previousFrame, to: updatedContentAreaInScreenSpace, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
                //self.clippingNode.layer.animateBoundsOriginYAdditive(from: 0.0, to: updatedContentAreaInScreenSpace.minY, duration: transitionDuration * animationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            }
            
            let intermediateCompletion: () -> Void = { [weak self, weak contentParentNode] in
                if completedEffect && completedContentNode && completedActionsNode {
                    switch result {
                    case .default, .custom, .justDismiss:
                        if let contentParentNode = contentParentNode {
                            contentParentNode.addSubnode(contentParentNode.contentNode)
                            contentParentNode.isExtractedToContextPreview = false
                            contentParentNode.isExtractedToContextPreviewUpdated?(false)
                        }
                    case .dismissWithoutContent:
                        break
                    }
                    
                    self?.clippingNode.view.mask = nil
                    
                    completion()
                }
            }
            
            if #available(iOS 10.0, *) {
                if let propertyAnimator = self.propertyAnimator {
                    let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                    propertyAnimator?.stopAnimation(true)
                }
                self.propertyAnimator = UIViewPropertyAnimator(duration: transitionDuration * UIView.animationDurationFactor(), curve: .easeInOut, animations: {
                    //self?.effectView.effect = nil
                })
            }
            
            if let _ = self.propertyAnimator {
                if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                    self.displayLinkAnimator = DisplayLinkAnimator(duration: 0.2 * contextAnimationDurationFactor * UIView.animationDurationFactor(), from: 0.0, to: 0.999, update: { [weak self] value in
                        (self?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                    }, completion: {
                        completedEffect = true
                        intermediateCompletion()
                    })
                }
                self.effectView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2 * contextAnimationDurationFactor, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
            } else {
                UIView.animate(withDuration: 0.21 * contextAnimationDurationFactor, animations: {
                    if #available(iOS 9.0, *) {
                        self.effectView.effect = nil
                    } else {
                        self.effectView.alpha = 0.0
                    }
                }, completion: { _ in
                    completedEffect = true
                    intermediateCompletion()
                })
            }
            
            if !self.dimNode.isHidden {
                self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * contextAnimationDurationFactor, removeOnCompletion: false)
            } else {
                self.withoutBlurDimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * contextAnimationDurationFactor, removeOnCompletion: false)
            }
            
            self.actionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15 * contextAnimationDurationFactor, removeOnCompletion: false, completion: { _ in
                completedActionsNode = true
                intermediateCompletion()
            })
            self.actionsContainerNode.layer.animateScale(from: 1.0, to: 0.1, duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            
            let animateOutToItem: Bool
            switch result {
            case .default, .custom, .justDismiss:
                animateOutToItem = true
            case .dismissWithoutContent:
                animateOutToItem = false
            }
            
            if animateOutToItem, let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                let localSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.scrollNode.view)
                let localContentSourceFrame: CGRect
                if keepInPlace {
                    localContentSourceFrame = self.view.convert(originalProjectedContentViewFrame.1, to: self.contentContainerNode.view.superview)
                } else {
                    localContentSourceFrame = localSourceFrame
                }
                
                var actionsOffset: CGFloat = 0.0
                if case let .extracted(source) = self.source, source.centerVertically {
                    actionsOffset = -localSourceFrame.width * 0.6
                }
                
                self.actionsContainerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: localSourceFrame.center.x - self.actionsContainerNode.position.x, y: localSourceFrame.center.y - self.actionsContainerNode.position.y + actionsOffset), duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false, additive: true)
                let contentContainerOffset = CGPoint(x: localContentSourceFrame.center.x - self.contentContainerNode.frame.center.x - contentParentNode.contentRect.minX, y: localContentSourceFrame.center.y - self.contentContainerNode.frame.center.y - contentParentNode.contentRect.minY)
                self.contentContainerNode.layer.animatePosition(from: CGPoint(), to: contentContainerOffset, duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false, additive: true, completion: { _ in
                    completedContentNode = true
                    intermediateCompletion()
                })
                contentParentNode.updateAbsoluteRect?(self.contentContainerNode.frame.offsetBy(dx: 0.0, dy: -self.scrollNode.view.contentOffset.y + contentContainerOffset.y), self.bounds.size)
                contentParentNode.applyAbsoluteOffset?(CGPoint(x: 0.0, y: -contentContainerOffset.y), transitionCurve, transitionDuration)
                
                contentParentNode.willUpdateIsExtractedToContextPreview?(false, .animated(duration: 0.2, curve: .easeInOut))
            } else {
                if let snapshotView = contentParentNode.contentNode.view.snapshotContentTree(keepTransform: true) {
                    self.contentContainerNode.view.addSubview(snapshotView)
                }
                
                contentParentNode.addSubnode(contentParentNode.contentNode)
                contentParentNode.isExtractedToContextPreview = false
                contentParentNode.isExtractedToContextPreviewUpdated?(false)
                
                self.contentContainerNode.allowsGroupOpacity = true
                self.contentContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * contextAnimationDurationFactor, removeOnCompletion: false, completion: { _ in
                    completedContentNode = true
                    intermediateCompletion()
                })
                
                contentParentNode.contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                contentParentNode.willUpdateIsExtractedToContextPreview?(false, .animated(duration: 0.2, curve: .easeInOut))
            }
        case let .controller(source):
            guard let maybeContentNode = self.contentContainerNode.contentNode, case let .controller(controller) = maybeContentNode else {
                return
            }
            
            let transitionInfo = source.transitionInfo()
            
            if transitionInfo == nil {
                result = .dismissWithoutContent
            }
            
            switch result {
            case let .custom(value):
                switch value {
                case let .animated(duration, curve):
                    transitionDuration = duration
                    transitionCurve = curve
                default:
                    break
                }
            default:
                break
            }
            
            self.isUserInteractionEnabled = false
            self.isAnimatingOut = true
            
            self.scrollNode.view.setContentOffset(self.scrollNode.view.contentOffset, animated: false)
            
            var completedEffect = false
            var completedContentNode = false
            var completedActionsNode = false
            
            if let transitionInfo = transitionInfo, let (sourceView, sourceNodeRect) = transitionInfo.sourceNode() {
                let projectedFrame = convertFrame(sourceNodeRect, from: sourceView, to: self.view)
                self.originalProjectedContentViewFrame = (projectedFrame, projectedFrame)
                
                var updatedContentAreaInScreenSpace = transitionInfo.contentAreaInScreenSpace
                updatedContentAreaInScreenSpace.origin.x = 0.0
                updatedContentAreaInScreenSpace.size.width = self.bounds.width
            }
            
            let intermediateCompletion: () -> Void = {
                if completedEffect && completedContentNode && completedActionsNode {
                    switch result {
                    case .default, .custom, .justDismiss:
                        break
                    case .dismissWithoutContent:
                        break
                    }
                    
                    completion()
                }
            }
            
            if #available(iOS 10.0, *) {
                if let propertyAnimator = self.propertyAnimator {
                    let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                    propertyAnimator?.stopAnimation(true)
                }
                self.propertyAnimator = UIViewPropertyAnimator(duration: transitionDuration * UIView.animationDurationFactor(), curve: .easeInOut, animations: { [weak self] in
                    self?.effectView.effect = nil
                })
            }
            
            if let _ = self.propertyAnimator {
                if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                    self.displayLinkAnimator = DisplayLinkAnimator(duration: 0.2 * contextAnimationDurationFactor * UIView.animationDurationFactor(), from: 0.0, to: 0.999, update: { [weak self] value in
                        (self?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                    }, completion: {
                        completedEffect = true
                        intermediateCompletion()
                    })
                }
                self.effectView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.05 * contextAnimationDurationFactor, delay: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
            } else {
                UIView.animate(withDuration: 0.21 * contextAnimationDurationFactor, animations: {
                    if #available(iOS 9.0, *) {
                        self.effectView.effect = nil
                    } else {
                        self.effectView.alpha = 0.0
                    }
                }, completion: { _ in
                    completedEffect = true
                    intermediateCompletion()
                })
            }
            
            if !self.dimNode.isHidden {
                self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * contextAnimationDurationFactor, removeOnCompletion: false)
            } else {
                self.withoutBlurDimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * contextAnimationDurationFactor, removeOnCompletion: false)
            }
            self.actionsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2 * contextAnimationDurationFactor, removeOnCompletion: false, completion: { _ in
                completedActionsNode = true
                intermediateCompletion()
            })
            self.contentContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2 * contextAnimationDurationFactor, removeOnCompletion: false, completion: { _ in
            })
            self.actionsContainerNode.layer.animateScale(from: 1.0, to: 0.1, duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            self.contentContainerNode.layer.animateScale(from: 1.0, to: 0.01, duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false)
            
            let animateOutToItem: Bool
            switch result {
            case .default, .custom, .justDismiss:
                animateOutToItem = true
            case .dismissWithoutContent:
                animateOutToItem = false
            }
            
            if animateOutToItem, let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
                let localSourceFrame = self.view.convert(CGRect(origin: CGPoint(x: originalProjectedContentViewFrame.1.minX, y: originalProjectedContentViewFrame.1.minY), size: CGSize(width: originalProjectedContentViewFrame.1.width, height: originalProjectedContentViewFrame.1.height)), to: self.scrollNode.view)
                
                self.actionsContainerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: localSourceFrame.center.x - self.actionsContainerNode.position.x, y: localSourceFrame.center.y - self.actionsContainerNode.position.y), duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false, additive: true)
                let contentContainerOffset = CGPoint(x: localSourceFrame.center.x - self.contentContainerNode.frame.center.x, y: localSourceFrame.center.y - self.contentContainerNode.frame.center.y)
                self.contentContainerNode.layer.animatePosition(from: CGPoint(), to: contentContainerOffset, duration: transitionDuration * contextAnimationDurationFactor, timingFunction: transitionCurve.timingFunction, removeOnCompletion: false, additive: true, completion: { [weak self] _ in
                    completedContentNode = true
                    if let strongSelf = self, let contentNode = strongSelf.contentContainerNode.contentNode, case let .controller(controller) = contentNode {
                        controller.sourceView.isHidden = false
                    }
                    intermediateCompletion()
                })
            } else {
                if let contentNode = self.contentContainerNode.contentNode, case let .controller(controller) = contentNode {
                    controller.sourceView.isHidden = false
                }
                
                if let snapshotView = controller.view.snapshotContentTree(keepTransform: true), needAddShapshot {
                    self.contentContainerNode.view.addSubview(snapshotView)
                }
                
                self.contentContainerNode.allowsGroupOpacity = true
                self.contentContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: transitionDuration * contextAnimationDurationFactor, removeOnCompletion: false, completion: { _ in
                    completedContentNode = true
                    intermediateCompletion()
                })
            }
        }
    }
    
    public init(needAddShapshot: Bool = true) {
        self.needAddShapshot = needAddShapshot
    }
}
