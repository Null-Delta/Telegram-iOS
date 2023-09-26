//
//  ChatListContextAnimationOutController.swift
//  TelegramUI
//
//  Created by Rustam on 28.08.2023.
//

import Foundation
import Display
import UIKit
import ContextUI
import ChatListUI
import AvatarNode
import WallpaperBackgroundNode
import ContactsPeerItem
import ChatTitleView
import ItemListPeerItem
public class ChatListContextAnimationOutController: ContextAnimationOutControllerProtocol {
    
    private let springDuration: Double = 0.40 * contextAnimationDurationFactor
    private let springDamping: CGFloat = 110.0
    private var currentScale: CGFloat = 1
    
    public func animate(in controller: ContextUI.ContextControllerNode, source: ContextUI.ContextContentSource, result initialResult: ContextUI.ContextMenuActionResult, completion: @escaping () -> Void) {
        
        if case let .controller(sourceController) = source {
            if let sourceNode = (sourceController.sourceNode as? ChatListItemNode)?.dublicateNode {
                animateChatListItem(
                    sourceNode: sourceNode,
                    controller: controller,
                    source: source,
                    initialResult: initialResult,
                    completion: completion
                )
            } else if let sourceNode = (sourceController.sourceNode as? ContactsPeerItemNode)?.dublicateNode {
                animateContactsPeerItem(
                    sourceNode: sourceNode,
                    controller: controller,
                    source: source,
                    initialResult: initialResult,
                    completion: completion
                )
            } else if let sourceNode = (sourceController.sourceNode as? ItemListPeerItemNode)?.duplicateNode {
                animateListPeerItem(
                    sourceNode: sourceNode,
                    controller: controller,
                    source: source,
                    initialResult: initialResult,
                    completion: completion
                )
            }
        }
    }
    
    private func animateListPeerItem(
        sourceNode: ItemListPeerItemNode,
        controller: ContextControllerNode,
        source: ContextContentSource,
        initialResult: ContextUI.ContextMenuActionResult,
        completion: @escaping () -> Void
    ) {
        guard
            case let .controller(contentNodeController) = controller.contentContainerNode.contentNode,
            let chatController = contentNodeController.controller as? ChatControllerImpl,
            case let .controller(sourceController) = source,
            let navigationBar = chatController.navigationBar
        else { return }
        
        currentScale = contentNodeController.transform.m11

        let contentContainerNode = controller.contentContainerNode
        
        controller.isUserInteractionEnabled = false
        controller.isAnimatingOut = true
                
        var result = initialResult
        
        let transitionInfo = sourceController.transitionInfo()
        
        if transitionInfo == nil {
            result = .dismissWithoutContent
        }

        let intermediateCompletion: (Bool) -> Void = {
            if $0 {
                switch result {
                case .default, .custom:
                    break
                case .dismissWithoutContent:
                    break
                }
                
                completion()
            }
        }

        if !controller.dimNode.isHidden {
            controller.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: springDuration / 2, removeOnCompletion: false)
        } else {
            controller.withoutBlurDimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: springDuration / 2, removeOnCompletion: false)
        }
        

        if #available(iOS 10.0, *) {
            if let propertyAnimator = controller.propertyAnimator {
                let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                propertyAnimator?.stopAnimation(true)
            }
            controller.propertyAnimator = UIViewPropertyAnimator(duration: springDuration, curve: .easeInOut, animations: { [weak controller] in
                controller?.effectView.effect = nil
            })
        }
        
        if let _ = controller.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                controller.displayLinkAnimator = DisplayLinkAnimator(duration: 0.2 * contextAnimationDurationFactor, from: 0.0, to: 0.999, update: { [weak controller] value in
                    (controller?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                }, completion: {})
            }
            controller.effectView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 1, delay: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
        } else {
            UIView.animate(withDuration: 0.21 * contextAnimationDurationFactor, animations: {
                if #available(iOS 9.0, *) {
                    controller.effectView.effect = nil
                } else {
                    controller.effectView.alpha = 0.0
                }
            })
        }

        if let originalProjectedContentViewFrame = controller.originalProjectedContentViewFrame {
            let localSourceFrame = controller.view.convert(CGRect(origin: CGPoint(x: originalProjectedContentViewFrame.1.minX, y: originalProjectedContentViewFrame.1.minY), size: CGSize(width: originalProjectedContentViewFrame.1.width, height: originalProjectedContentViewFrame.1.height)), to: controller.scrollNode.view)

            let startFrame = localSourceFrame
            let endFrame = contentContainerNode.frame

            let chatListTitleCenter = sourceNode.titleNode.view.globalFrame!.center
            let NavigationBarTitleCenter = navigationBar.titleView!.subviews[0].subviews[0].subviews[0].subviews[0].globalFrame!.center
            let titleOffset = CGPoint(x: chatListTitleCenter.x - NavigationBarTitleCenter.x, y: chatListTitleCenter.y - NavigationBarTitleCenter.y)
            sourceNode.alpha = 1
            sourceNode.layer.animateAlpha(from: 0, to: 1, duration: springDuration / 3)

            sourceNode.avatarNode.layer.animateSpring(
                from: CATransform3DScale(CATransform3DIdentity, 0.5, 0.5, 1) as NSValue,
                to: CATransform3DIdentity as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            sourceNode.avatarNode.layer.animateSpring(
                from: -sourceNode.avatarNode.frame.height * 0.3 as NSValue,
                to:  0 as NSValue,
                keyPath: "position.y",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            sourceNode.backgroundNode.layer.animateSpring(
                from: -(sourceNode.backgroundNode.frame.height - navigationBar.backgroundNode.frame.height) * (1 / currentScale) as NSValue,
                to: 0 as NSValue,
                keyPath: "position.y",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )

            sourceNode.titleNode.layer.animateSpring(
                from: CGPoint(x: -titleOffset.x, y: -titleOffset.y) as NSValue,
                to: CGPoint.zero as NSValue,
                keyPath: "position",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            sourceNode.titleNode.layer.animateSpring(
                from: CATransform3DScale(CATransform3DIdentity, currentScale / contextScale, currentScale / contextScale, 1) as NSValue,
                to:  CATransform3DIdentity as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                removeOnCompletion: false
            )
            
            animateChat(
                controller: controller,
                source: source,
                startFrame: startFrame,
                endFrame: endFrame,
                titleOffset: titleOffset,
                intermediateCompletion: intermediateCompletion
            )
        }

    }
    
    private func animateContactsPeerItem(
        sourceNode: ContactsPeerItemNode,
        controller: ContextControllerNode,
        source: ContextContentSource,
        initialResult: ContextUI.ContextMenuActionResult,
        completion: @escaping () -> Void
    ) {
        guard
            case let .controller(contentNodeController) = controller.contentContainerNode.contentNode,
            let chatController = contentNodeController.controller as? ChatControllerImpl,
            case let .controller(sourceController) = source,
            let navigationBar = chatController.navigationBar
        else { return }
        
        currentScale = contentNodeController.transform.m11

        let contentContainerNode = controller.contentContainerNode
        
        controller.isUserInteractionEnabled = false
        controller.isAnimatingOut = true
                
        var result = initialResult
        
        let transitionInfo = sourceController.transitionInfo()
        
        if transitionInfo == nil {
            result = .dismissWithoutContent
        }

        let intermediateCompletion: (Bool) -> Void = {
            if $0 {
                switch result {
                case .default, .custom:
                    break
                case .dismissWithoutContent:
                    break
                }
                
                completion()
            }
        }

        if !controller.dimNode.isHidden {
            controller.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: springDuration / 2, removeOnCompletion: false)
        } else {
            controller.withoutBlurDimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: springDuration / 2, removeOnCompletion: false)
        }
        

        if #available(iOS 10.0, *) {
            if let propertyAnimator = controller.propertyAnimator {
                let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                propertyAnimator?.stopAnimation(true)
            }
            controller.propertyAnimator = UIViewPropertyAnimator(duration: springDuration, curve: .easeInOut, animations: { [weak controller] in
                controller?.effectView.effect = nil
            })
        }
        
        if let _ = controller.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                controller.displayLinkAnimator = DisplayLinkAnimator(duration: 0.2 * contextAnimationDurationFactor, from: 0.0, to: 0.999, update: { [weak controller] value in
                    (controller?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                }, completion: {})
            }
            controller.effectView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 1, delay: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
        } else {
            UIView.animate(withDuration: 0.21 * contextAnimationDurationFactor, animations: {
                if #available(iOS 9.0, *) {
                    controller.effectView.effect = nil
                } else {
                    controller.effectView.alpha = 0.0
                }
            })
        }

        if let originalProjectedContentViewFrame = controller.originalProjectedContentViewFrame {
            let insets = controller.contentInsets
            let localSourceFrame = controller.view.convert(
                CGRect(
                    origin: CGPoint(
                        x: originalProjectedContentViewFrame.1.minX + insets.left,
                        y: originalProjectedContentViewFrame.1.minY + insets.top),
                    size: CGSize(
                        width: originalProjectedContentViewFrame.1.width - insets.left - insets.right,
                        height: originalProjectedContentViewFrame.1.height - insets.top - insets.bottom
                    )
                ),
                to: controller.scrollNode.view
            )

            let startFrame = localSourceFrame
            let endFrame = contentContainerNode.frame

            let chatListTitleCenter = sourceNode.titleNode.view.globalFrame!.center
            let NavigationBarTitleCenter = navigationBar.titleView!.subviews[0].subviews[0].subviews[0].subviews[0].globalFrame!.center
            let titleOffset = CGPoint(x: chatListTitleCenter.x - NavigationBarTitleCenter.x, y: chatListTitleCenter.y - NavigationBarTitleCenter.y)
            sourceNode.alpha = 1
            sourceNode.layer.animateAlpha(from: 0, to: 1, duration: springDuration / 3)

            sourceNode.avatarNodeContainer.layer.animateSpring(
                from: CATransform3DScale(CATransform3DIdentity, 0.5, 0.5, 1) as NSValue,
                to: CATransform3DIdentity as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            sourceNode.avatarNodeContainer.layer.animateSpring(
                from: -sourceNode.avatarNodeContainer.frame.height * 0.3 as NSValue,
                to:  0 as NSValue,
                keyPath: "position.y",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            sourceNode.backgroundNode.layer.animateSpring(
                from: -(sourceNode.backgroundNode.frame.height - navigationBar.backgroundNode.frame.height) * (1 / currentScale) as NSValue,
                to: 0 as NSValue,
                keyPath: "position.y",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )

            sourceNode.contextSourceNode.layer.animateSpring(
                from: CATransform3DTranslate(CATransform3DIdentity, -titleOffset.x, -titleOffset.y, 0) as NSValue,
                to: CATransform3DIdentity as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            sourceNode.titleNode.layer.animateSpring(
                from: CATransform3DScale(CATransform3DIdentity, currentScale / contextScale, currentScale / contextScale, 1) as NSValue,
                to:  CATransform3DIdentity as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                removeOnCompletion: false
            )
            
            animateChat(
                controller: controller,
                source: source,
                startFrame: startFrame,
                endFrame: endFrame,
                titleOffset: titleOffset,
                intermediateCompletion: intermediateCompletion
            )
        }

    }
    
    private func animateChatListItem(
        sourceNode: ChatListItemNode,
        controller: ContextControllerNode,
        source: ContextContentSource,
        initialResult: ContextUI.ContextMenuActionResult,
        completion: @escaping () -> Void
    ) {
        guard
            case let .controller(contentNodeController) = controller.contentContainerNode.contentNode,
            case let .controller(sourceController) = source,
            let sourceNode = (sourceController.sourceNode as? ChatListItemNode)?.dublicateNode
        else { return }
        
        currentScale = contentNodeController.transform.m11

        let contentContainerNode = controller.contentContainerNode
        
        controller.isUserInteractionEnabled = false
        controller.isAnimatingOut = true
                
        var result = initialResult
        
        let transitionInfo = sourceController.transitionInfo()
        
        if transitionInfo == nil {
            result = .dismissWithoutContent
        }

        let intermediateCompletion: (Bool) -> Void = {
            if $0 {
                switch result {
                case .default, .custom:
                    break
                case .dismissWithoutContent:
                    break
                }
                
                completion()
            }
        }

        if !controller.dimNode.isHidden {
            controller.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: springDuration / 2, removeOnCompletion: false)
        } else {
            controller.withoutBlurDimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: springDuration / 2, removeOnCompletion: false)
        }
        

        if #available(iOS 10.0, *) {
            if let propertyAnimator = controller.propertyAnimator {
                let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                propertyAnimator?.stopAnimation(true)
            }
            controller.propertyAnimator = UIViewPropertyAnimator(duration: springDuration, curve: .easeInOut, animations: { [weak controller] in
                controller?.effectView.effect = nil
            })
        }
        
        if let _ = controller.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                controller.displayLinkAnimator = DisplayLinkAnimator(duration: 0.2 * contextAnimationDurationFactor, from: 0.0, to: 0.999, update: { [weak controller] value in
                    (controller?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                }, completion: {})
            }
            controller.effectView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 1, delay: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
        } else {
            UIView.animate(withDuration: 0.21 * contextAnimationDurationFactor, animations: {
                if #available(iOS 9.0, *) {
                    controller.effectView.effect = nil
                } else {
                    controller.effectView.alpha = 0.0
                }
            })
        }

        if let originalProjectedContentViewFrame = controller.originalProjectedContentViewFrame {
            let localSourceFrame = controller.view.convert(CGRect(origin: CGPoint(x: originalProjectedContentViewFrame.1.minX, y: originalProjectedContentViewFrame.1.minY), size: CGSize(width: originalProjectedContentViewFrame.1.width, height: originalProjectedContentViewFrame.1.height)), to: controller.scrollNode.view)

            let startFrame = localSourceFrame
            let endFrame = contentContainerNode.frame

            let chatListTitleCenter = sourceNode.titleNode.view.globalFrame!.center
            
            var NavigationBarTitleCenter: CGPoint = .zero
            
            if contentNodeController.controller is ChatControllerImpl,
               let navigationBar = contentNodeController.controller.navigationBar {
                NavigationBarTitleCenter = navigationBar.titleView!.subviews[0].subviews[0].subviews[0].subviews[0].globalFrame!.center
            } else {
                NavigationBarTitleCenter = contentNodeController.view.subviews[0].subviews[3].subviews[3].subviews[0].subviews[0].subviews[0].subviews[1].subviews[0].globalFrame!.center
            }
            
            let titleOffset = CGPoint(x: chatListTitleCenter.x - NavigationBarTitleCenter.x, y: chatListTitleCenter.y - NavigationBarTitleCenter.y)
            sourceNode.alpha = 1
            sourceNode.layer.animateAlpha(from: 0, to: 1, duration: springDuration / 3)

            sourceNode.avatarContainerNode.layer.animateSpring(
                from: CATransform3DScale(CATransform3DIdentity, 0.5, 0.5, 1) as NSValue,
                to: CATransform3DIdentity as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            sourceNode.avatarContainerNode.layer.animateSpring(
                from: -sourceNode.avatarContainerNode.frame.height * 0.3 as NSValue,
                to:  0 as NSValue,
                keyPath: "position.y",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            if let navigationBar = contentNodeController.controller.navigationBar {
                sourceNode.backgroundNode.layer.animateSpring(
                    from: -(sourceNode.backgroundNode.frame.height - navigationBar.backgroundNode.frame.height) * (1 / currentScale) as NSValue,
                    to: 0 as NSValue,
                    keyPath: "position.y",
                    duration: springDuration,
                    initialVelocity: 0.0,
                    damping: springDamping,
                    additive: true
                )
            }

            sourceNode.mainContentContainerNode.layer.animateSpring(
                from: CATransform3DTranslate(CATransform3DIdentity, -titleOffset.x, -titleOffset.y, 0) as NSValue,
                to: CATransform3DIdentity as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            sourceNode.titleNode.layer.animateSpring(
                from: CATransform3DScale(CATransform3DIdentity, currentScale / contextScale, currentScale / contextScale, 1) as NSValue,
                to:  CATransform3DIdentity as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                removeOnCompletion: false
            )
            
            if contentNodeController.controller is ChatControllerImpl {
                animateChat(
                    controller: controller,
                    source: source,
                    startFrame: startFrame,
                    endFrame: endFrame,
                    titleOffset: titleOffset,
                    intermediateCompletion: intermediateCompletion
                )
            } else {
                animateForum(
                    controller: controller,
                    source: source,
                    startFrame: startFrame,
                    endFrame: endFrame,
                    titleOffset: titleOffset,
                    intermediateCompletion: intermediateCompletion
                )
            }
        }
    }
    
    private func animateForum(
        controller: ContextUI.ContextControllerNode,
        source: ContextUI.ContextContentSource,
        startFrame: CGRect,
        endFrame: CGRect,
        titleOffset: CGPoint,
        intermediateCompletion: @escaping (Bool) -> Void
    ) {
        guard
            case let .controller(contentNodeController) = controller.contentContainerNode.contentNode
        else { return }
        
        var completedContentNode = false

        let contentContainerNode = controller.contentContainerNode
        let actionsContainerNode = controller.actionsContainerNode

        contentContainerNode.layer.cornerRadius = 0
        contentContainerNode.layer.animate(
            from: contentContainerNode.cornerRadius as NSValue,
            to: 0 as NSValue,
            keyPath: "cornerRadius",
            timingFunction: "linear",
            duration: springDuration / 3
        )
                    
        contentContainerNode.layer.animateSpring(
            from: endFrame.width as NSValue,
            to: startFrame.width as NSValue,
            keyPath: "bounds.size.width",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            removeOnCompletion: false
        )
                    
        contentContainerNode.layer.animateSpring(
            from: contentContainerNode.frame.height as NSValue,
            to: startFrame.height as NSValue,
            keyPath: "bounds.size.height",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            removeOnCompletion: false
        )
                                
        contentContainerNode.layer.animateSpring(
            from: 0 as NSValue,
            to: (startFrame.origin.y - endFrame.center.y + startFrame.height / 2) as NSValue,
            keyPath: "position.y",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            removeOnCompletion: false,
            additive: true
        )

        contentContainerNode.layer.animateSpring(
            from: 0 as NSValue,
            to:  startFrame.center.x - endFrame.center.x as NSValue,
            keyPath: "position.x",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            removeOnCompletion: false,
            additive: true
        )
    
        let chatTitleView = contentNodeController.view.subviews[0].subviews[3].subviews[3].subviews[0].subviews[0].subviews[0].subviews[1].subviews[0] as? ChatTitleView

        chatTitleView?.layer.animateSpring(
            from: CATransform3DIdentity as NSValue,
            to: CATransform3DScale(
                CATransform3DTranslate(
                    CATransform3DIdentity,
                    titleOffset.x * (1 / (currentScale / contextScale)),
                    titleOffset.y * (1 / (currentScale / contextScale)),
                    0
                ),
                1 / (currentScale / contextScale),
                1 / (currentScale / contextScale),
                1
            ) as NSValue,
            keyPath: "transform",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )
        
        
        actionsContainerNode.layer.animateSpring(
            from: NSValue(cgPoint: CGPoint()),
            to: NSValue(cgPoint: CGPoint(x: startFrame.center.x - actionsContainerNode.position.x, y: startFrame.center.y - actionsContainerNode.position.y)),
            keyPath: "position",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            additive: true,
            completion: { _ in
                completedContentNode = true
                contentContainerNode.alpha = 0
                intermediateCompletion(completedContentNode)
            }
        )
        actionsContainerNode.alpha = 0
        actionsContainerNode.layer.animateAlpha(
            from: 1,
            to: 0,
            duration: 0.2 * contextAnimationDurationFactor
        )
        
        actionsContainerNode.layer.animateSpring(
            from: 1.0 as NSNumber,
            to: 0.1 as NSNumber,
            keyPath: "transform.scale",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )
    }
    
    private func animateChat(
        controller: ContextUI.ContextControllerNode,
        source: ContextUI.ContextContentSource,
        startFrame: CGRect,
        endFrame: CGRect,
        titleOffset: CGPoint,
        intermediateCompletion: @escaping (Bool) -> Void
    ) {
        guard
            case let .controller(contentNodeController) = controller.contentContainerNode.contentNode,
            let chatController = contentNodeController.controller as? ChatControllerImpl,
            let navigationBar = chatController.navigationBar,
            let chatBackgroundNode = chatController.chatDisplayNode.backgroundNode as? WallpaperBackgroundNodeImpl
        else { return }
        
        var completedContentNode = false

        let contentContainerNode = controller.contentContainerNode
        let actionsContainerNode = controller.actionsContainerNode

        contentContainerNode.layer.cornerRadius = 0
        contentContainerNode.layer.animate(
            from: contentContainerNode.cornerRadius as NSValue,
            to: 0 as NSValue,
            keyPath: "cornerRadius",
            timingFunction: "linear",
            duration: springDuration / 3
        )
                    
        contentContainerNode.layer.animateSpring(
            from: endFrame.width as NSValue,
            to: startFrame.width as NSValue,
            keyPath: "bounds.size.width",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            removeOnCompletion: false
        )
                    
        contentContainerNode.layer.animateSpring(
            from: contentContainerNode.frame.height as NSValue,
            to: startFrame.height as NSValue,
            keyPath: "bounds.size.height",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            removeOnCompletion: false
        )
                                
        contentContainerNode.layer.animateSpring(
            from: 0 as NSValue,
            to: (startFrame.origin.y - endFrame.center.y + startFrame.height / 2) as NSValue,
            keyPath: "position.y",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            removeOnCompletion: false,
            additive: true
        )
        
        contentContainerNode.layer.animateSpring(
            from: 0 as NSValue,
            to:  startFrame.center.x - endFrame.center.x as NSValue,
            keyPath: "position.x",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            removeOnCompletion: false,
            additive: true
        )
        
        chatBackgroundNode.layer.removeAllAnimations()
        chatBackgroundNode.isLayoutBlocked = false
        chatBackgroundNode.updateLayout(size: CGSize(
            width: startFrame.width * (1 / currentScale),
            height: startFrame.height * (1 / currentScale)
        ), displayMode: .aspectFit, transition: .animated(duration: springDuration, curve: .customSpring(damping: springDamping, initialVelocity: 0.0)))
        chatBackgroundNode.layer.animateSpring(
            from: CGSize(
                width: endFrame.width * (1 / currentScale),
                height: endFrame.height * (1 / currentScale)
            ) as NSValue,
            to: CGSize(
                width: startFrame.width * (1 / currentScale),
                height: startFrame.height * (1 / currentScale)
            ) as NSValue,
            keyPath: "bounds.size",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )
        chatBackgroundNode.layer.animateSpring(
            from: chatBackgroundNode.layer.position as NSValue,
            to: CGPoint(
                x: (startFrame.width) / 2 * (1 / currentScale),
                y: (startFrame.height) / 2 * (1 / currentScale)
            ) as NSValue,
            keyPath: "position",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )
        
        
        
        navigationBar.titleView!.subviews[0].subviews[0].layer.animateSpring(
            from: CATransform3DIdentity as NSValue,
            to: CATransform3DScale(
                CATransform3DTranslate(
                    CATransform3DIdentity,
                    titleOffset.x * (1 / (currentScale / contextScale)),
                    titleOffset.y * (1 / (currentScale / contextScale)),
                    0
                ),
                1 / (currentScale / contextScale),
                1 / (currentScale / contextScale),
                1
            ) as NSValue,
            keyPath: "transform",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )
        
        let oldSize = navigationBar.backgroundNode.frame.size

        navigationBar.backgroundNode.update(
            size: CGSize(
                width: startFrame.width * (1 / currentScale),
                height: startFrame.height * (1 / currentScale)
            ),
            transition: .animated(duration: springDuration, curve: .customSpring(damping: springDamping, initialVelocity: 0.0))
        )
        navigationBar.stripeNode.layer.animateSpring(
            from: 0 as NSValue,
            to: -(oldSize.height - startFrame.height * (1 / currentScale)) as NSValue,
            keyPath: "position.y",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            additive: true
        )

        
        
        
        actionsContainerNode.layer.animateSpring(
            from: NSValue(cgPoint: CGPoint()),
            to: NSValue(cgPoint: CGPoint(x: startFrame.center.x - actionsContainerNode.position.x, y: startFrame.center.y - actionsContainerNode.position.y)),
            keyPath: "position",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            additive: true,
            completion: { _ in
                completedContentNode = true
                contentContainerNode.alpha = 0
                intermediateCompletion(completedContentNode)
            }
        )
        actionsContainerNode.alpha = 0
        actionsContainerNode.layer.animateAlpha(
            from: 1,
            to: 0,
            duration: 0.2 * contextAnimationDurationFactor
        )
        
        actionsContainerNode.layer.animateSpring(
            from: 1.0 as NSNumber,
            to: 0.1 as NSNumber,
            keyPath: "transform.scale",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )
        
    }
}
