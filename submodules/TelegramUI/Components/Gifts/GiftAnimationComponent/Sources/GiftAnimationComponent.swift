import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AppBundle
import AccountContext
import EmojiTextAttachmentView
import TextFormat

public final class GiftAnimationComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let file: TelegramMediaFile?
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        file: TelegramMediaFile?
    ) {
        self.context = context
        self.theme = theme
        self.file = file
    }

    public static func ==(lhs: GiftAnimationComponent, rhs: GiftAnimationComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.file != rhs.file {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var component: GiftAnimationComponent?
        private weak var componentState: EmptyComponentState?
        
        private var animationLayer: InlineStickerItemLayer?
                
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: GiftAnimationComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
                        
            let emoji = ChatTextInputTextCustomEmojiAttribute(
                interactivelySelectedFromPackId: nil,
                fileId: component.file?.fileId.id ?? 0,
                file: component.file
            )
            
            let iconSize = availableSize
            if self.animationLayer == nil {
                let animationLayer = InlineStickerItemLayer(
                    context: .account(component.context),
                    userLocation: .other,
                    attemptSynchronousLoad: false,
                    emoji: emoji,
                    file: component.file,
                    cache: component.context.animationCache,
                    renderer: component.context.animationRenderer,
                    unique: true,
                    placeholderColor: component.theme.list.mediaPlaceholderColor,
                    pointSize: CGSize(width: iconSize.width * 1.2, height: iconSize.height * 1.2),
                    loopCount: 1
                )
                animationLayer.isVisibleForAnimations = true
                self.animationLayer = animationLayer
                self.layer.addSublayer(animationLayer)
            }
            if let animationLayer = self.animationLayer {
                transition.setFrame(layer: animationLayer, frame: CGRect(origin: .zero, size: iconSize))
            }
            
            return iconSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
