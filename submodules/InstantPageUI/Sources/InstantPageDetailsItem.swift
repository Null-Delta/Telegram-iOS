import Foundation
import UIKit
import TelegramCore
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

public final class InstantPageDetailsItem: InstantPageItem {
    public var frame: CGRect
    public let wantsNode: Bool = true
    public let separatesTiles: Bool = true
    public var medias: [InstantPageMedia] {
        var result: [InstantPageMedia] = []
        for item in self.items {
            result.append(contentsOf: item.medias)
        }
        return result
    }

    public let titleItems: [InstantPageItem]
    public let titleHeight: CGFloat
    public let items: [InstantPageItem]
    let safeInset: CGFloat
    let rtl: Bool
    public let initiallyExpanded: Bool
    public let index: Int
    
    init(frame: CGRect, titleItems: [InstantPageItem], titleHeight: CGFloat, items: [InstantPageItem], safeInset: CGFloat, rtl: Bool, initiallyExpanded: Bool, index: Int) {
        self.frame = frame
        self.titleItems = titleItems
        self.titleHeight = titleHeight
        self.items = items
        self.safeInset = safeInset
        self.rtl = rtl
        self.initiallyExpanded = initiallyExpanded
        self.index = index
    }
    
    public func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourceLocation: InstantPageSourceLocation, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?, getPreloadedResource: @escaping (String) -> Data?) -> InstantPageNode? {
        var expanded: Bool?
        if let expandedDetails = currentExpandedDetails, let currentlyExpanded = expandedDetails[self.index] {
            expanded = currentlyExpanded
        }
        return InstantPageDetailsNode(context: context, sourceLocation: sourceLocation, strings: strings, nameDisplayOrder: nameDisplayOrder, theme: theme, item: self, openMedia: openMedia, longPressMedia: longPressMedia, activatePinchPreview: activatePinchPreview, pinchPreviewFinished: pinchPreviewFinished, openPeer: openPeer, openUrl: openUrl, currentlyExpanded: expanded, updateDetailsExpanded: updateDetailsExpanded, getPreloadedResource: getPreloadedResource)
    }
    
    public func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    public func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageDetailsNode {
            return self === node.item
        } else {
            return false
        }
    }
    
    public func distanceThresholdGroup() -> Int? {
        return 8
    }
    
    public func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return CGFloat.greatestFiniteMagnitude
    }
    
    public func drawInTile(context: CGContext) {
    }
    
    public func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        if point.y < self.titleHeight {
            for item in self.titleItems {
                if item.frame.contains(point) {
                    let rects = item.linkSelectionRects(at: point.offsetBy(dx: -item.frame.minX, dy: -item.frame.minY))
                    return rects.map { $0.offsetBy(dx: item.frame.minX, dy: item.frame.minY) }
                }
            }
        } else {
            let convertedPoint = point.offsetBy(dx: 0.0, dy: -self.titleHeight)
            for item in self.items {
                if item.frame.contains(convertedPoint) {
                    let rects = item.linkSelectionRects(at: convertedPoint.offsetBy(dx: -item.frame.minX, dy: -item.frame.minY))
                    if !rects.isEmpty {
                        return rects.map { $0.offsetBy(dx: item.frame.minX, dy: item.frame.minY + self.titleHeight) }
                    }
                }
            }
        }
        return []
    }
}

func layoutDetailsItem(theme: InstantPageTheme, title: NSAttributedString, boundingWidth: CGFloat, items: [InstantPageItem], contentSize: CGSize, safeInset: CGFloat, rtl: Bool, initiallyExpanded: Bool, index: Int) -> InstantPageDetailsItem {
    let detailsInset: CGFloat = 17.0 + safeInset
    let titleInset: CGFloat = 22.0
    
    let (_, titleItems, titleSize) = layoutTextItemWithString(title, boundingWidth: boundingWidth - detailsInset * 2.0 - titleInset, offset: CGPoint(x: detailsInset + titleInset, y: 0.0))
    let titleHeight = max(44.0, titleSize.height + 26.0)
    var offset: CGFloat?
    for var item in titleItems {
        var itemOffset = floorToScreenPixels((titleHeight - item.frame.height) / 2.0)
        if item is InstantPageTextItem {
            offset = itemOffset
        } else if let offset = offset {
            itemOffset = offset
        }
        item.frame = item.frame.offsetBy(dx: 0.0, dy: itemOffset)
    }
    
    return InstantPageDetailsItem(frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: contentSize.height + titleHeight), titleItems: titleItems, titleHeight: titleHeight, items: items, safeInset: safeInset, rtl: rtl, initiallyExpanded: initiallyExpanded, index: index)
}
