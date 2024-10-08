import Foundation
import UIKit
import TelegramCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

public final class InstantPageAudioItem: InstantPageItem {
    public var frame: CGRect
    public let wantsNode: Bool = true
    public let separatesTiles: Bool = false
    public let medias: [InstantPageMedia]
    
    let media: InstantPageMedia
    let webpage: TelegramMediaWebpage
    
    public init(frame: CGRect, media: InstantPageMedia, webpage: TelegramMediaWebpage) {
        self.frame = frame
        self.media = media
        self.webpage = webpage
        self.medias = [media]
    }
    
    public func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourceLocation: InstantPageSourceLocation, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?, getPreloadedResource: @escaping (String) -> Data?) -> InstantPageNode? {
        return InstantPageAudioNode(context: context, strings: strings, theme: theme, webPage: self.webpage, media: self.media, openMedia: openMedia)
    }
    
    public func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    public func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageAudioNode {
            return self.media == node.media
        } else {
            return false
        }
    }
    
    public func distanceThresholdGroup() -> Int? {
        return 4
    }
    
    public func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 1000.0
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
    
    public func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
    
    public func drawInTile(context: CGContext) {
    }
}

