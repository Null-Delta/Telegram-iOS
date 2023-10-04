//
//  ChatListContextAnimationInController.swift
//  ContextUI
//
//  Created by Rustam on 25.08.2023.
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


extension UIView {
    var globalFrame: CGRect? {
        let rootView = UIApplication.shared.keyWindow?.rootViewController?.view
        return self.superview?.convert(self.frame, to: rootView)
    }
}

public class ChatListContextAnimationInController: ContextAnimationInControllerProtocol {
    
    private let springDuration: Double = 0.52 * contextAnimationDurationFactor
    private let springDamping: CGFloat = 110.0
    private var currentScale: CGFloat = 1

    public func animate(with contentNode: ContextContentNode, in controller: ContextControllerNode, source: ContextContentSource) {
        if case let .controller(sourceController) = source {
            sourceController.sourceNode?.alpha = 0

            if let sourceNode = (sourceController.sourceNode as? ChatListItemNode)?.dublicateNode {
                animateChatListItem(
                    sourceNode: sourceNode,
                    contentNode: contentNode,
                    controller: controller,
                    source: source
                )
            } else if let sourceNode = (sourceController.sourceNode as? ContactsPeerItemNode)?.dublicateNode {
                sourceNode.separatorNode.alpha = 0
                sourceNode.topSeparatorNode.alpha = 0
                
                if case let .controller(contentNodeController) = contentNode, contentNodeController.controller is ChatControllerImpl {
                    animateContactsPeerItem(
                        sourceNode: sourceNode,
                        contentNode: contentNode,
                        controller: controller,
                        source: source
                    )
                } else {
                    animateContactsPeerForumItem(
                        sourceNode: sourceNode,
                        contentNode: contentNode,
                        controller: controller,
                        source: source
                    )
                }
            } else if let sourceNode = (sourceController.sourceNode as? ItemListPeerItemNode)?.duplicateNode {
                animateListPeerItem(
                    sourceNode: sourceNode,
                    contentNode: contentNode,
                    controller: controller,
                    source: source
                )
            }
        }
    }
    
    private func animateListPeerItem(
        sourceNode: ItemListPeerItemNode,
        contentNode: ContextContentNode,
        controller: ContextControllerNode,
        source: ContextContentSource
    ) {
        guard
            case let .controller(contentNodeController) = contentNode,
            let chatController = contentNodeController.controller as? ChatControllerImpl,
            let navigationBar = chatController.navigationBar
        else {
            return
        }

        sourceNode.alpha = 1
        
        let actionsContainerNode = controller.actionsContainerNode
        let contentContainerNode = controller.contentContainerNode
        
        var titleOffset: CGPoint = .zero
        currentScale = contentNodeController.transform.m11

        actionsContainerNode.layer.animateAlpha(
            from: 0.0,
            to: 1.0,
            duration: 0.2 * contextAnimationDurationFactor
        )

        actionsContainerNode.layer.animateSpring(
            from: 0.1 as NSNumber,
            to: 1.0 as NSNumber,
            keyPath: "transform.scale",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )

        contentContainerNode.allowsGroupOpacity = true

        if let originalProjectedContentViewFrame = controller.originalProjectedContentViewFrame {
            let localSourceFrame = controller.view.convert(CGRect(origin: CGPoint(x: originalProjectedContentViewFrame.1.minX, y: originalProjectedContentViewFrame.1.minY), size: CGSize(width: originalProjectedContentViewFrame.1.width, height: originalProjectedContentViewFrame.1.height)), to: controller.scrollNode.view)
            
            let startFrame = localSourceFrame
            let endFrame = contentContainerNode.frame

            let chatItemScale = (localSourceFrame.width + 12) / localSourceFrame.width

            contentContainerNode.addSubnode(sourceNode)
            sourceNode.frame.origin = .zero
            sourceNode.bottomStripeNode.alpha = 0

            var chatListTitleCenter = sourceNode.titleNode.view.globalFrame!.center
            chatListTitleCenter.x -= contentContainerNode.frame.minX
            chatListTitleCenter.x *= contextScale
            chatListTitleCenter.x += contentContainerNode.frame.minX
            chatListTitleCenter.y -= contentContainerNode.frame.minY
            chatListTitleCenter.y *= contextScale
            chatListTitleCenter.y += contentContainerNode.frame.minY

            let NavigationBarTitleCenter = navigationBar.titleView!.subviews[0].subviews[0].subviews[0].subviews[0].globalFrame!.center

            titleOffset = CGPoint(x: NavigationBarTitleCenter.x - chatListTitleCenter.x, y: NavigationBarTitleCenter.y - chatListTitleCenter.y)
            titleOffset.x /= contextScale
            titleOffset.y /= contextScale

            //MARK: - chat list item
            sourceNode.allowsGroupOpacity = true
            sourceNode.alpha = 0
            sourceNode.layer.animateAlpha(from: 1, to: 0, duration: springDuration / 3, removeOnCompletion: false)
            sourceNode.layer.animateSpring(
                from: CATransform3DScale(
                    CATransform3DIdentity,
                    chatItemScale * contextScale,
                    chatItemScale * contextScale,
                    1
                ) as NSValue,
                to: CATransform3DScale(
                    CATransform3DIdentity,
                    contextScale,
                    contextScale,
                    1
                ) as NSValue,
                keyPath: "transform",
                duration: 0.1,
                initialVelocity: 0.0,
                damping: springDamping,
                removeOnCompletion: false
            )
            
            sourceNode.backgroundNode.layer.animateSpring(
                from: sourceNode.backgroundNode.frame.size as NSValue,
                to: CGSize(
                    width: endFrame.width * (1 / contextScale),
                    height: navigationBar.backgroundNode.frame.height * currentScale * (1 / contextScale)
                )
                     as NSValue,
                keyPath: "bounds.size",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            sourceNode.backgroundNode.layer.animateSpring(
                from: CGPoint.zero as NSValue,
                to: CGPoint(
                    x: -(sourceNode.backgroundNode.frame.width - endFrame.width * (1 / contextScale)) / 2,
                    y: -(sourceNode.backgroundNode.frame.height - navigationBar.backgroundNode.frame.height * currentScale * (1 / contextScale)) / 2
                ) as NSValue,
                keyPath: "position",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            sourceNode.avatarNode.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to: CATransform3DScale(CATransform3DIdentity, 0.5, 0.5, 1) as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            sourceNode.avatarNode.layer.animateSpring(
                from: 0 as NSValue,
                to:  -sourceNode.avatarNode.frame.height * 0.3  as NSValue,
                keyPath: "position.y",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                removeOnCompletion: false,
                additive: true
            )
            
            sourceNode.titleNode.layer.animateSpring(
                from: CGPoint.zero as NSValue,
                to:   CGPoint(x: titleOffset.x, y: titleOffset.y)  as NSValue,
                keyPath: "position",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            var fontScale = 1.0
            if case let .controller(contentNodeController) = contentNode,
               let chatController = contentNodeController.controller as? ChatControllerImpl {
                let titleFontSize = floor(sourceNode.layoutParams!.0.presentationData.fontSize.itemListBaseFontSize)
                fontScale = (chatController.chatTitleView?.titleFont.pointSize ?? titleFontSize) / titleFontSize
            }
            
            sourceNode.titleNode.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to:  CATransform3DScale(CATransform3DIdentity, currentScale / contextScale * fontScale, currentScale / contextScale * fontScale, 1)  as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            
            animateChat(
                contentNode: contentNode,
                controller: controller,
                source: source,
                startFrame: startFrame,
                endFrame: endFrame,
                titleOffset: titleOffset,
                titleFontSize: sourceNode.layoutParams!.0.presentationData.fontSize.itemListBaseFontSize
            )
        }
        
        contextScale = contentNodeController.transform.m11
    }
    
    private func animateContactsPeerItem(
        sourceNode: ContactsPeerItemNode,
        contentNode: ContextContentNode,
        controller: ContextControllerNode,
        source: ContextContentSource
    ) {
        guard
            case let .controller(contentNodeController) = contentNode,
            let chatController = contentNodeController.controller as? ChatControllerImpl,
            let navigationBar = chatController.navigationBar
        else {
            return
        }

        sourceNode.alpha = 1
        
        let actionsContainerNode = controller.actionsContainerNode
        let contentContainerNode = controller.contentContainerNode
        
        var titleOffset: CGPoint = .zero
        currentScale = contentNodeController.transform.m11

        actionsContainerNode.layer.animateAlpha(
            from: 0.0,
            to: 1.0,
            duration: 0.2 * contextAnimationDurationFactor
        )

        actionsContainerNode.layer.animateSpring(
            from: 0.1 as NSNumber,
            to: 1.0 as NSNumber,
            keyPath: "transform.scale",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )

        contentContainerNode.allowsGroupOpacity = true

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

            let chatItemScale = (localSourceFrame.width + 12) / localSourceFrame.width

            contentContainerNode.addSubnode(sourceNode)
            sourceNode.frame.origin = .zero
            sourceNode.separatorNode.alpha = 0

            var chatListTitleCenter = sourceNode.titleNode.view.globalFrame!.center
            chatListTitleCenter.x -= contentContainerNode.frame.minX
            chatListTitleCenter.x *= contextScale
            chatListTitleCenter.x += contentContainerNode.frame.minX
            chatListTitleCenter.y -= contentContainerNode.frame.minY
            chatListTitleCenter.y *= contextScale
            chatListTitleCenter.y += contentContainerNode.frame.minY

            let NavigationBarTitleCenter = navigationBar.titleView!.subviews[0].subviews[0].subviews[0].subviews[0].globalFrame!.center

            titleOffset = CGPoint(x: NavigationBarTitleCenter.x - chatListTitleCenter.x, y: NavigationBarTitleCenter.y - chatListTitleCenter.y)
            titleOffset.x /= contextScale
            titleOffset.y /= contextScale

            //MARK: - chat list item
            sourceNode.contextSourceNode.allowsGroupOpacity = true
            sourceNode.alpha = 0
            sourceNode.layer.animateAlpha(from: 1, to: 0, duration: springDuration / 3, removeOnCompletion: false)
            sourceNode.layer.animateSpring(
                from: CATransform3DScale(
                    CATransform3DIdentity,
                    chatItemScale * contextScale,
                    chatItemScale * contextScale,
                    1
                ) as NSValue,
                to: CATransform3DScale(
                    CATransform3DIdentity,
                    contextScale,
                    contextScale,
                    1
                ) as NSValue,
                keyPath: "transform",
                duration: 0.1,
                initialVelocity: 0.0,
                damping: springDamping,
                removeOnCompletion: false
            )
                        
            sourceNode.backgroundNode.layer.animateSpring(
                from: sourceNode.backgroundNode.frame.size as NSValue,
                to: CGSize(
                    width: endFrame.width * (1 / contextScale),
                    height: navigationBar.backgroundNode.frame.height * currentScale * (1 / contextScale)
                )
                     as NSValue,
                keyPath: "bounds.size",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            sourceNode.backgroundNode.layer.animateSpring(
                from: CGPoint.zero as NSValue,
                to: CGPoint(
                    x: -(sourceNode.backgroundNode.frame.width - endFrame.width * (1 / contextScale)) / 2,
                    y: -(sourceNode.backgroundNode.frame.height - navigationBar.backgroundNode.frame.height * currentScale * (1 / contextScale)) / 2
                ) as NSValue,
                keyPath: "position",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            sourceNode.avatarNodeContainer.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to: CATransform3DScale(CATransform3DIdentity, 0.5, 0.5, 1) as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            sourceNode.avatarNodeContainer.layer.animateSpring(
                from: 0 as NSValue,
                to:  -sourceNode.avatarNodeContainer.frame.height * 0.3  as NSValue,
                keyPath: "position.y",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                removeOnCompletion: false,
                additive: true
            )
            
            sourceNode.offsetContainerNode.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to:   CATransform3DTranslate(CATransform3DIdentity, titleOffset.x, titleOffset.y, 0)  as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            var fontScale = 1.0
            if case let .controller(contentNodeController) = contentNode,
               let chatController = contentNodeController.controller as? ChatControllerImpl {
                let titleFontSize = floor(sourceNode.item!.presentationData.fontSize.itemListBaseFontSize)
                fontScale = (chatController.chatTitleView?.titleFont.pointSize ?? titleFontSize) / titleFontSize
            }

            sourceNode.titleNode.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to:  CATransform3DScale(CATransform3DIdentity, currentScale / contextScale * fontScale, currentScale / contextScale * fontScale, 1)  as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            
            sourceNode.credibilityIconView?.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to:  CATransform3DScale(CATransform3DIdentity, currentScale / contextScale, currentScale / contextScale, 1)  as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            
            animateChat(
                contentNode: contentNode,
                controller: controller,
                source: source,
                startFrame: startFrame,
                endFrame: endFrame,
                titleOffset: titleOffset,
                titleFontSize: sourceNode.item!.presentationData.fontSize.itemListBaseFontSize
            )
        }
        
        contextScale = contentNodeController.transform.m11
    }
    
    private func animateContactsPeerForumItem(
        sourceNode: ContactsPeerItemNode,
        contentNode: ContextContentNode,
        controller: ContextControllerNode,
        source: ContextContentSource
    ) {
        guard
            case let .controller(contentNodeController) = contentNode
        else {
            return
        }

        sourceNode.alpha = 1
        
        let actionsContainerNode = controller.actionsContainerNode
        let contentContainerNode = controller.contentContainerNode
        
        var titleOffset: CGPoint = .zero
        currentScale = contentNodeController.transform.m11

        actionsContainerNode.layer.animateAlpha(
            from: 0.0,
            to: 1.0,
            duration: 0.2 * contextAnimationDurationFactor
        )

        actionsContainerNode.layer.animateSpring(
            from: 0.1 as NSNumber,
            to: 1.0 as NSNumber,
            keyPath: "transform.scale",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )

        contentContainerNode.allowsGroupOpacity = true

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

            let chatItemScale = (localSourceFrame.width + 12) / localSourceFrame.width

            contentContainerNode.addSubnode(sourceNode)
            sourceNode.frame.origin = .zero
            sourceNode.separatorNode.alpha = 0

            var chatListTitleCenter = sourceNode.titleNode.view.globalFrame!.center
            chatListTitleCenter.x -= contentContainerNode.frame.minX
            chatListTitleCenter.x *= contextScale
            chatListTitleCenter.x += contentContainerNode.frame.minX
            chatListTitleCenter.y -= contentContainerNode.frame.minY
            chatListTitleCenter.y *= contextScale
            chatListTitleCenter.y += contentContainerNode.frame.minY

            let NavigationBarTitleCenter = contentNodeController.view.subviews[0].subviews[3].subviews[2].subviews[0].subviews[0].subviews[0].subviews[1].subviews[0].subviews[0].subviews[0].globalFrame!.center

            titleOffset = CGPoint(x: NavigationBarTitleCenter.x - chatListTitleCenter.x, y: NavigationBarTitleCenter.y - chatListTitleCenter.y)
            titleOffset.x /= contextScale
            titleOffset.y /= contextScale

            //MARK: - chat list item
            sourceNode.contextSourceNode.allowsGroupOpacity = true
            sourceNode.alpha = 0
            sourceNode.layer.animateAlpha(from: 1, to: 0, duration: springDuration / 3, removeOnCompletion: false)
            sourceNode.layer.animateSpring(
                from: CATransform3DScale(
                    CATransform3DIdentity,
                    chatItemScale * contextScale,
                    chatItemScale * contextScale,
                    1
                ) as NSValue,
                to: CATransform3DScale(
                    CATransform3DIdentity,
                    contextScale,
                    contextScale,
                    1
                ) as NSValue,
                keyPath: "transform",
                duration: 0.1,
                initialVelocity: 0.0,
                damping: springDamping,
                removeOnCompletion: false
            )
                        
//            sourceNode.backgroundNode.layer.animateSpring(
//                from: sourceNode.backgroundNode.frame.size as NSValue,
//                to: CGSize(
//                    width: endFrame.width * (1 / contextScale),
//                    height: navigationBar.backgroundNode.frame.height * currentScale * (1 / contextScale)
//                )
//                     as NSValue,
//                keyPath: "bounds.size",
//                duration: springDuration,
//                initialVelocity: 0.0,
//                damping: springDamping
//            )
//            sourceNode.backgroundNode.layer.animateSpring(
//                from: CGPoint.zero as NSValue,
//                to: CGPoint(
//                    x: -(sourceNode.backgroundNode.frame.width - endFrame.width * (1 / contextScale)) / 2,
//                    y: -(sourceNode.backgroundNode.frame.height - navigationBar.backgroundNode.frame.height * currentScale * (1 / contextScale)) / 2
//                ) as NSValue,
//                keyPath: "position",
//                duration: springDuration,
//                initialVelocity: 0.0,
//                damping: springDamping,
//                additive: true
//            )
            
            sourceNode.avatarNodeContainer.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to: CATransform3DScale(CATransform3DIdentity, 0.5, 0.5, 1) as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            sourceNode.avatarNodeContainer.layer.animateSpring(
                from: 0 as NSValue,
                to:  -sourceNode.avatarNodeContainer.frame.height * 0.3  as NSValue,
                keyPath: "position.y",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                removeOnCompletion: false,
                additive: true
            )
            
            sourceNode.offsetContainerNode.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to:   CATransform3DTranslate(CATransform3DIdentity, titleOffset.x, titleOffset.y, 0)  as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            var fontScale = 1.0
            if case let .controller(contentNodeController) = contentNode,
               let chatController = contentNodeController.controller as? ChatControllerImpl {
                let titleFontSize = floor(sourceNode.item!.presentationData.fontSize.itemListBaseFontSize)
                fontScale = (chatController.chatTitleView?.titleFont.pointSize ?? titleFontSize) / titleFontSize
            }

            sourceNode.titleNode.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to:  CATransform3DScale(CATransform3DIdentity, currentScale / contextScale * fontScale, currentScale / contextScale * fontScale, 1)  as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            
            sourceNode.credibilityIconView?.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to:  CATransform3DScale(CATransform3DIdentity, currentScale / contextScale, currentScale / contextScale, 1)  as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            
            animateForum(
                contentNode: contentNode,
                controller: controller,
                source: source,
                startFrame: startFrame,
                endFrame: endFrame,
                titleOffset: titleOffset,
                titleFontSize: sourceNode.item!.presentationData.fontSize.itemListBaseFontSize
            )
        }
        
        contextScale = contentNodeController.transform.m11
    }
    
    
    private func navigationBar(from controller: UIViewController) -> NavigationBar? {
        if let controller = controller as? ChatControllerImpl {
            return controller.navigationBar
        } else if let controller = controller as? ChatListControllerImpl {
            return controller.transitionNavigationBar
        } else {
            return nil
        }
    }
    private func animateChatListItem(
        sourceNode: ChatListItemNode,
        contentNode: ContextContentNode,
        controller: ContextControllerNode,
        source: ContextContentSource
    ) {
        guard
            case let .controller(contentNodeController) = contentNode
        else {
            return
        }
        
        sourceNode.alpha = 1
                                
        let actionsContainerNode = controller.actionsContainerNode
        let contentContainerNode = controller.contentContainerNode
        
        
        var titleOffset: CGPoint = .zero
        currentScale = contentNodeController.transform.m11

        actionsContainerNode.layer.animateAlpha(
            from: 0.0,
            to: 1.0,
            duration: 0.2 * contextAnimationDurationFactor
        )
        
        actionsContainerNode.layer.animateSpring(
            from: 0.1 as NSNumber,
            to: 1.0 as NSNumber,
            keyPath: "transform.scale",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )
        
        contentContainerNode.allowsGroupOpacity = true

        if let originalProjectedContentViewFrame = controller.originalProjectedContentViewFrame {
            let localSourceFrame = controller.view.convert(CGRect(origin: CGPoint(x: originalProjectedContentViewFrame.1.minX, y: originalProjectedContentViewFrame.1.minY), size: CGSize(width: originalProjectedContentViewFrame.1.width, height: originalProjectedContentViewFrame.1.height)), to: controller.scrollNode.view)

            let startFrame = localSourceFrame
            let endFrame = contentContainerNode.frame
            
            let chatItemScale = (localSourceFrame.width + 12) / localSourceFrame.width

            contentContainerNode.addSubnode(sourceNode)
            sourceNode.frame.origin = .zero
            
            var chatListTitleCenter = sourceNode.titleNode.view.globalFrame!.center
            chatListTitleCenter.x -= contentContainerNode.frame.minX
            chatListTitleCenter.x *= contextScale
            chatListTitleCenter.x += contentContainerNode.frame.minX
            chatListTitleCenter.y -= contentContainerNode.frame.minY
            chatListTitleCenter.y *= contextScale
            chatListTitleCenter.y += contentContainerNode.frame.minY

            var NavigationBarTitleCenter: CGPoint = .zero
            
            if contentNodeController.controller is ChatControllerImpl,
               let navigationBar = navigationBar(from: contentNodeController.controller) {
                NavigationBarTitleCenter = navigationBar.titleView!.subviews[0].subviews[0].subviews[0].subviews[0].globalFrame!.center
            } else if contentNodeController.controller is ChatListControllerImpl {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    let contentNodeController = contentNodeController
                    print(contentNodeController)
                }
                
                if contentNodeController.view.subviews[0].subviews[3].subviews[2].subviews[0].subviews[0].subviews[0].subviews.count == 1 {
                    NavigationBarTitleCenter = contentNodeController.view.subviews[0].subviews[3].subviews[2].subviews[1].subviews[3].globalFrame!.center
                } else {
                    NavigationBarTitleCenter = contentNodeController.view.subviews[0].subviews[3].subviews[2].subviews[0].subviews[0].subviews[0].subviews[1].subviews[0].subviews[0].subviews[0].globalFrame!.center
                }
            } else {
                NavigationBarTitleCenter = .zero
            }
            

            titleOffset = CGPoint(x: NavigationBarTitleCenter.x - chatListTitleCenter.x, y: NavigationBarTitleCenter.y - chatListTitleCenter.y)
            titleOffset.x /= contextScale
            titleOffset.y /= contextScale

            sourceNode.mainContentContainerNode.allowsGroupOpacity = true
            sourceNode.alpha = 0
            sourceNode.layer.animateAlpha(from: 1, to: 0, duration: springDuration / 3, removeOnCompletion: false)

            sourceNode.frame.origin.x -= (sourceNode.frame.width - startFrame.width) / 2
            sourceNode.frame.origin.y -= (sourceNode.frame.height - sourceNode.frame.height * contextScale) / 2
            sourceNode.layer.animateSpring(
                from: CATransform3DScale(
                    CATransform3DIdentity,
                    chatItemScale * contextScale,
                    chatItemScale * contextScale,
                    1
                ) as NSValue,
                to: CATransform3DScale(
                    CATransform3DIdentity,
                    contextScale,
                    contextScale,
                    1
                ) as NSValue,
                keyPath: "transform",
                duration: 0.1,
                initialVelocity: 0.0,
                damping: springDamping,
                removeOnCompletion: false
            )
                        
            if let navigationBar = navigationBar(from: contentNodeController.controller) {
                sourceNode.backgroundNode.layer.animateSpring(
                    from: sourceNode.backgroundNode.frame.size as NSValue,
                    to: CGSize(
                        width: endFrame.width * (1 / contextScale),
                        height: navigationBar.backgroundNode.frame.height * currentScale * (1 / contextScale)
                    )
                    as NSValue,
                    keyPath: "bounds.size",
                    duration: springDuration,
                    initialVelocity: 0.0,
                    damping: springDamping
                )
                
                sourceNode.backgroundNode.layer.animateSpring(
                    from: CGPoint.zero as NSValue,
                    to: CGPoint(
                        x: -(sourceNode.backgroundNode.frame.width - endFrame.width * (1 / contextScale)) / 2,
                        y: -(sourceNode.backgroundNode.frame.height - navigationBar.backgroundNode.frame.height * currentScale * (1 / contextScale)) / 2
                    ) as NSValue,
                    keyPath: "position",
                    duration: springDuration,
                    initialVelocity: 0.0,
                    damping: springDamping,
                    additive: true
                )
            }
            
            sourceNode.avatarContainerNode.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to: CATransform3DScale(CATransform3DIdentity, 0.5, 0.5, 1) as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            sourceNode.avatarContainerNode.layer.animateSpring(
                from: 0 as NSValue,
                to:  -sourceNode.avatarContainerNode.frame.height * 0.3  as NSValue,
                keyPath: "position.y",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                removeOnCompletion: false,
                additive: true
            )
            
            sourceNode.mainContentContainerNode.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to:   CATransform3DTranslate(CATransform3DIdentity, titleOffset.x, titleOffset.y, 0)  as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            var fontScale = 1.0
            if case let .controller(contentNodeController) = contentNode,
               let chatController = contentNodeController.controller as? ChatControllerImpl {
                let titleFontSize = floor(sourceNode.item!.presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0)
                fontScale = (chatController.chatTitleView?.titleFont.pointSize ?? titleFontSize) / titleFontSize
            }

            sourceNode.titleNode.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to:  CATransform3DScale(CATransform3DIdentity, currentScale / contextScale * fontScale, currentScale / contextScale * fontScale, 1)  as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            sourceNode.credibilityIconView?.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to:  CATransform3DScale(CATransform3DIdentity, currentScale / contextScale, currentScale / contextScale, 1)  as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            
            if contentNodeController.controller is ChatControllerImpl {
                animateChat(
                    contentNode: contentNode,
                    controller: controller,
                    source: source,
                    startFrame: startFrame,
                    endFrame: endFrame,
                    titleOffset: titleOffset,
                    titleFontSize: floor(sourceNode.item!.presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0)
                )
            } else {
                animateForum(
                    contentNode: contentNode,
                    controller: controller,
                    source: source,
                    startFrame: startFrame,
                    endFrame: endFrame,
                    titleOffset: titleOffset,
                    titleFontSize: floor(sourceNode.item!.presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0)
                )
            }
        }
        contextScale = contentNodeController.transform.m11
    }
    
    private func animateForum(
        contentNode: ContextContentNode,
        controller: ContextControllerNode,
        source: ContextContentSource,
        startFrame: CGRect,
        endFrame: CGRect,
        titleOffset: CGPoint,
        titleFontSize: CGFloat
    ) {
        guard
            case let .controller(contentNodeController) = contentNode
        else {
            return
        }

        let contentContainerNode = controller.contentContainerNode

        //MARK: - container
        
        contentContainerNode.layer.animateSpring(
            from: startFrame.size as NSValue,
            to: endFrame.size as NSValue,
            keyPath: "bounds.size",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )

        contentContainerNode.layer.animateSpring(
            from: 0 as NSNumber,
            to: 14 as NSNumber,
            keyPath: "cornerRadius",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )
        contentContainerNode.layer.animateSpring(
            from: CGPoint(
                x: startFrame.midX - endFrame.midX,
                y: startFrame.midY - endFrame.midY
            ) as NSValue,
            to: CGPoint.zero as NSValue,
            keyPath: "position",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            additive: true,
            completion: { [weak controller] _ in
                controller?.animatedIn = true
                contentContainerNode.isLayoutLocked = false
            }
        )
        
        //MARK: - navigation
        
        switch controller.source {
        case let .controller(controller):
            controller.animatedIn()
        default:
            break
        }
        
        var chatTitleView: UIView? = nil

        if contentNodeController.view.subviews[0].subviews[3].subviews[2].subviews[0].subviews[0].subviews[0].subviews.count == 1 {
            chatTitleView = contentNodeController.view.subviews[0].subviews[3].subviews[2].subviews[1].subviews[3]
        } else {
            chatTitleView = contentNodeController.view.subviews[0].subviews[3].subviews[2].subviews[0].subviews[0].subviews[0].subviews[1].subviews[0]
        }

        let fontScale = ((chatTitleView as? ChatTitleView)?.titleFont.pointSize ?? titleFontSize) / titleFontSize
        chatTitleView?.layer.animateSpring(
            from: CATransform3DScale(
                CATransform3DTranslate(
                    CATransform3DIdentity,
                    -titleOffset.x * (1 / (currentScale / contextScale)),
                    -titleOffset.y * (1 / (currentScale / contextScale)),
                    0
                ),
                1 / (currentScale / contextScale) / fontScale,
                1 / (currentScale / contextScale) / fontScale,
                1
            )
             as NSValue,
            to:  CATransform3DScale(
                CATransform3DIdentity,
                1,
                1,
                1
            )as NSValue,
            keyPath: "transform",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )

        controller.actionsContainerNode.layer.animateSpring(
            from: NSValue(cgPoint: CGPoint(x: startFrame.origin.x - controller.actionsContainerNode.position.x, y: startFrame.center.y - controller.actionsContainerNode.position.y)),
            to: NSValue(cgPoint: CGPoint()),
            keyPath: "position",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            additive: true
        )
        
    }
    
    private func animateChat(
        contentNode: ContextContentNode,
        controller: ContextControllerNode,
        source: ContextContentSource,
        startFrame: CGRect,
        endFrame: CGRect,
        titleOffset: CGPoint,
        titleFontSize: CGFloat
    ) {
        guard
            case let .controller(contentNodeController) = contentNode,
            let chatController = contentNodeController.controller as? ChatControllerImpl,
            let navigationBar = chatController.navigationBar,
            let chatBackgroundNode = chatController.chatDisplayNode.backgroundNode as? WallpaperBackgroundNodeImpl
        else {
            return
        }
        
        
        chatController.chatDisplayNode.inputPanelBackgroundSeparatorNode.isHidden = true
        chatController.chatDisplayNode.inputPanelBottomBackgroundSeparatorNode.isHidden = true
        navigationBar.stripeNode.alpha = 0
        

        let contentContainerNode = controller.contentContainerNode

        //MARK: - background
        
        chatBackgroundNode.layer.animateSpring(
            from: CGSize(
                width: startFrame.width * (1 / currentScale),
                height: startFrame.height * (1 / currentScale)
            ) as NSValue,
            to: CGSize(
                width: endFrame.width * (1 / currentScale),
                height: endFrame.height * (1 / currentScale)
            ) as NSValue,
            keyPath: "bounds.size",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )
        chatBackgroundNode.layer.animateSpring(
            from: CGPoint(
                x: (startFrame.width - endFrame.width) / 2 * (1 / currentScale),
                y: (startFrame.height - endFrame.height) / 2 * (1 / currentScale)
            ) as NSValue,
            to: CGPoint.zero as NSValue,
            keyPath: "position",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            additive: true
        )
        chatBackgroundNode.updateLayout(
            size: CGSize(
                width: startFrame.width * (1 / currentScale),
                height: startFrame.height * (1 / currentScale)
                    ),
            displayMode: .aspectFill,
            transition: .immediate
        )
        chatBackgroundNode.updateLayout(
            size: CGSize(
                width: endFrame.width * (1 / currentScale),
                height: endFrame.height * (1 / currentScale)
                    ),
            displayMode: .aspectFill,
            transition: .animated(duration: springDuration, curve: .customSpring(damping: springDamping, initialVelocity: 0.0))
        )
                    
        chatBackgroundNode.isLayoutBlocked = true
        
        
        //MARK: - container
        
        contentContainerNode.layer.animateSpring(
            from: startFrame.size as NSValue,
            to: endFrame.size as NSValue,
            keyPath: "bounds.size",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )

        contentContainerNode.layer.animateSpring(
            from: 0 as NSNumber,
            to: 14 as NSNumber,
            keyPath: "cornerRadius",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )
        contentContainerNode.layer.animateSpring(
            from: CGPoint(
                x: startFrame.midX - endFrame.midX,
                y: startFrame.midY - endFrame.midY
            ) as NSValue,
            to: CGPoint.zero as NSValue,
            keyPath: "position",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            additive: true,
            completion: { [weak controller] _ in
                controller?.animatedIn = true
                contentContainerNode.isLayoutLocked = false
                chatBackgroundNode.isLayoutBlocked = false
                navigationBar.stripeNode.alpha = 1
            }
        )
        
        //MARK: - messages

        chatController.chatDisplayNode.historyNodeContainer.layer.animateSpring(
            from: (startFrame.width - endFrame.width) / 2 as NSNumber,
            to: 0 as NSNumber,
            keyPath: "position.x",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            additive: true
        )
        
        //MARK: - navigation
        
        switch controller.source {
        case let .controller(controller):
            controller.animatedIn()
        default:
            break
        }
        
        let oldSize = navigationBar.backgroundNode.frame.size
        navigationBar.backgroundNode.update(size: CGSize(width: startFrame.width * (1 / currentScale), height: startFrame.height * (1 / currentScale)), transition: .immediate)
        navigationBar.backgroundNode.update(size: CGSize(width: endFrame.width * (1 / currentScale), height: oldSize.height), transition: .animated(duration: springDuration, curve: .customSpring(damping: springDamping, initialVelocity: 0.0)))
        navigationBar.stripeNode.layer.animateSpring(
            from: oldSize.height - startFrame.height * (1 / currentScale) as NSValue,
            to: 0 as NSValue,
            keyPath: "position.y",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )
        
        let fontScale = (chatController.chatTitleView?.titleFont.pointSize ?? titleFontSize) / titleFontSize
        navigationBar.titleView!.subviews[0].subviews[0].layer.animateSpring(
            from: CATransform3DScale(
                CATransform3DTranslate(
                    CATransform3DIdentity,
                    -titleOffset.x * (1 / (currentScale / contextScale)),
                    -titleOffset.y * (1 / (currentScale / contextScale)),
                    0
                ),
                1 / (currentScale / contextScale) / fontScale,
                1 / (currentScale / contextScale) / fontScale,
                1
            )
             as NSValue,
            to:  CATransform3DScale(
                CATransform3DIdentity,
                1,
                1,
                1
            )as NSValue,
            keyPath: "transform",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )

        //chatController.chatTitleView?.titleFont = Font.medium(titleFontSize)
        //chatController.chatTitleView?.titleContent = chatController.chatTitleView?.titleContent
                                    
        controller.actionsContainerNode.layer.animateSpring(
            from: NSValue(cgPoint: CGPoint(x: startFrame.origin.x - controller.actionsContainerNode.position.x, y: startFrame.center.y - controller.actionsContainerNode.position.y)),
            to: NSValue(cgPoint: CGPoint()),
            keyPath: "position",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping,
            additive: true
        )
    }
    
    public init() { }
}

