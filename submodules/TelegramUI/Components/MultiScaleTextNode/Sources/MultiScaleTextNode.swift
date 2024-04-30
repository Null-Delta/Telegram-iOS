import Foundation
import UIKit
import AsyncDisplayKit
import Display

private final class MultiScaleTextStateNode: ASDisplayNode {
    let tintTextNode: ImmediateTextNode
    let noTintTextNode: ImmediateTextNode
    
    var currentLayout: MultiScaleTextLayout?
    
    override init() {
        self.tintTextNode = ImmediateTextNode()
        self.tintTextNode.displaysAsynchronously = false
        self.tintTextNode.renderContentTypes = TextNode.RenderContentTypes.all.subtracting(TextNode.RenderContentTypes.emoji)
        
        self.noTintTextNode = ImmediateTextNode()
        self.noTintTextNode.displaysAsynchronously = false
        self.noTintTextNode.renderContentTypes = .emoji
        
        super.init()
        
        self.addSubnode(self.tintTextNode)
        self.addSubnode(self.noTintTextNode)
    }
}

public final class MultiScaleTextState {
    public struct Attributes {
        public var font: UIFont
        public var color: UIColor
        public var alignment: NSTextAlignment
        public var shadowColor: UIColor?
        public var maximumNumberOfLines: Int?

        public init(font: UIFont, color: UIColor, alignment: NSTextAlignment = .left, shadowColor: UIColor? = nil, maximumNumberOfLines: Int? = nil) {
            self.font = font
            self.color = color
            self.alignment = alignment
            self.shadowColor = shadowColor
            self.maximumNumberOfLines = maximumNumberOfLines
        }
    }
    
    public let attributes: Attributes
    public let constrainedSize: CGSize
    
    public init(attributes: Attributes, constrainedSize: CGSize) {
        self.attributes = attributes
        self.constrainedSize = constrainedSize
    }
}

public struct MultiScaleTextLayout {
    public var size: CGSize
    public var linesCount: Int
    public var lastLineWidth: CGFloat

    public init(size: CGSize, linesCount: Int, lastLineWidth: CGFloat) {
        self.size = size
        self.linesCount = linesCount
        self.lastLineWidth = lastLineWidth
    }
}

public final class MultiScaleTextNode: ASDisplayNode {
    private let stateNodes: [AnyHashable: MultiScaleTextStateNode]
    
    public init(stateKeys: [AnyHashable]) {
        self.stateNodes = Dictionary(stateKeys.map { ($0, MultiScaleTextStateNode()) }, uniquingKeysWith: { lhs, _ in lhs })
        
        super.init()
        
        for (_, node) in self.stateNodes {
            self.addSubnode(node)
        }
    }
    
    public func stateNode(forKey key: AnyHashable) -> ASDisplayNode? {
        return self.stateNodes[key]?.tintTextNode
    }
    
    public func updateTintColor(color: UIColor, transition: ContainedViewLayoutTransition) {
        for (_, node) in self.stateNodes {
            transition.updateTintColor(layer: node.tintTextNode.layer, color: color)
        }
    }
    
    public func updateLayout(text: String, states: [AnyHashable: MultiScaleTextState], mainState: AnyHashable) -> [AnyHashable: MultiScaleTextLayout] {
        assert(Set(states.keys) == Set(self.stateNodes.keys))
        assert(states[mainState] != nil)
        
        var result: [AnyHashable: MultiScaleTextLayout] = [:]
        var mainLayout: MultiScaleTextLayout?
        for (key, state) in states {
            if let node = self.stateNodes[key] {
                node.tintTextNode.attributedText = NSAttributedString(string: text, attributes: [
                    .font: state.attributes.font,
                    .foregroundColor: state.attributes.color
                ])
                node.noTintTextNode.attributedText = NSAttributedString(string: text, attributes: [
                    .font: state.attributes.font,
                    .foregroundColor: state.attributes.color
                ])
                if let shadowColor = state.attributes.shadowColor {
                    node.tintTextNode.textShadowColor = shadowColor
                    node.tintTextNode.textShadowBlur = 3.0
                    node.noTintTextNode.textShadowColor = shadowColor
                    node.noTintTextNode.textShadowBlur = 3.0
                } else {
                    node.tintTextNode.shadowColor = nil
                    node.noTintTextNode.shadowColor = nil
                }

                node.tintTextNode.textAlignment = state.attributes.alignment
                node.noTintTextNode.textAlignment = state.attributes.alignment

                node.tintTextNode.maximumNumberOfLines = state.attributes.maximumNumberOfLines ?? 1
                node.noTintTextNode.maximumNumberOfLines = state.attributes.maximumNumberOfLines ?? 1

                node.tintTextNode.isAccessibilityElement = true
                node.tintTextNode.accessibilityLabel = text
                node.noTintTextNode.isAccessibilityElement = false
                let nodeSize = node.tintTextNode.updateLayout(state.constrainedSize)
                let _ = node.noTintTextNode.updateLayout(state.constrainedSize)

                let lineHeight: CGFloat = node.tintTextNode.attributedText.map {
                    $0.boundingRect(
                        with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                        context: nil
                    ).height
                } ?? 0

                let linesCount = Int(round(nodeSize.height / lineHeight))
                let nodeLayout = MultiScaleTextLayout(
                    size: nodeSize,
                    linesCount: linesCount,
                    lastLineWidth: lastLineMaxX(
                        message: NSAttributedString(
                            string: text,
                            attributes: [
                                .font: state.attributes.font,
                                .foregroundColor: state.attributes.color,
                            ]
                        ),
                        labelWidth: nodeSize.width,
                        linesCount: state.attributes.maximumNumberOfLines ?? 1
                    )
                )
                if key == mainState {
                    mainLayout = nodeLayout
                }
                node.currentLayout = nodeLayout
                result[key] = nodeLayout
            }
        }
        if let mainLayout = mainLayout {
            let mainBounds = CGRect(origin: CGPoint(x: -mainLayout.size.width / 2.0, y: -mainLayout.size.height / 2.0), size: mainLayout.size)
            for (key, _) in states {
                if let node = self.stateNodes[key], let nodeLayout = result[key] {
                    let textFrame = CGRect(origin: CGPoint(x: mainBounds.minX, y: mainBounds.minY + floor((mainBounds.height - nodeLayout.size.height) / 2.0)), size: nodeLayout.size)
                    node.tintTextNode.frame = textFrame
                    node.noTintTextNode.frame = textFrame
                }
            }
        }
        return result
    }
    
    private func lastLineMaxX(message: NSAttributedString, labelWidth: CGFloat, linesCount: Int) -> CGFloat {
        if linesCount == 1 { return labelWidth }

        let labelSize = CGSize(width: labelWidth, height: .infinity)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: labelSize)
        let textStorage = NSTextStorage(attributedString: message)
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textContainer.lineFragmentPadding = 0.0
        textContainer.lineBreakMode = .byTruncatingTail
        textContainer.maximumNumberOfLines = 2
        let lastGlyphIndex = layoutManager.glyphIndexForCharacter(at: message.length - 1)
        let lastLineFragmentRect = layoutManager.lineFragmentUsedRect(
            forGlyphAt: lastGlyphIndex,
            effectiveRange: nil
        )

        return lastLineFragmentRect.maxX
    }

    public func update(stateFractions: [AnyHashable: CGFloat], alpha: CGFloat = 1.0, transition: ContainedViewLayoutTransition) {
        var fractionSum: CGFloat = 0.0
        for (_, fraction) in stateFractions {
            fractionSum += fraction
        }
        for (key, fraction) in stateFractions {
            if let node = self.stateNodes[key], let _ = node.currentLayout {
                if !transition.isAnimated {
                    node.layer.removeAllAnimations()
                }
                transition.updateAlpha(node: node, alpha: fraction / fractionSum * alpha)
            }
        }
    }
}
