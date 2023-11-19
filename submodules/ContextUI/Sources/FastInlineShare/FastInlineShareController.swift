//
//  FastInlineShareController.swift
//  _LocalDebugOptions
//
//  Created by Rustam Khakhuk on 07.11.2023.
//

import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import AccountContext
import TelegramPresentationData
import UIKit
import AsyncDisplayKit

public let fastInlineShareAnimationSpeed: Double = 0.8
public let fastInlineShareAnimationSpring: Double = 0.75

public final class FastInlineShareController: ViewController {
    
    private let accountContext: AccountContext
    private var presentationData: PresentationData

    private let contextGesture: ContextGesture
    
    private let fastInlineShareView: FastInlineShareView
    private let sourceNode: ASDisplayNode
    private let sourceOrigin: () -> CGPoint
    private let sourceFrame: () -> CGRect
    private let style: FastInlineShareView.Style
    private var wasOpenAnimationFinished = false
    private let peerSelected: (Peer, UIView) -> Void
    private var wasFinishStart: Bool = false

    private var currentPeers: [Peer] = [] {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                
                for index in 0..<strongSelf.currentPeers.count {
                    let avatar = strongSelf.fastInlineShareView.avatars[index]
                    let nameLabel = strongSelf.fastInlineShareView.namesLabels[index]
                    let nameBackground = strongSelf.fastInlineShareView.namesBackgrounds[index]
                    
                    avatar.setPeer(
                        context: strongSelf.accountContext,
                        theme: strongSelf.presentationData.theme,
                        peer: EnginePeer(strongSelf.currentPeers[index]),
                        overrideImage: strongSelf.currentPeers[index].id == strongSelf.accountContext.account.peerId ? .savedMessagesIcon : nil,
                        clipStyle: .round,
                        synchronousLoad: true,
                        displayDimensions: CGSize(width: 48, height: 48)
                    )

                    nameLabel.text = strongSelf.currentPeers[index].id == strongSelf.accountContext.account.peerId ? strongSelf.presentationData.strings.DialogList_SavedMessages : EnginePeer(strongSelf.currentPeers[index]).compactDisplayTitle
                    nameLabel.lineBreakMode = .byTruncatingTail
                    nameLabel.sizeToFit()
                    nameLabel.frame.size.width = min(120, nameLabel.frame.size.width)
                    
                    nameLabel.frame.origin.y = 4
                    nameLabel.frame.origin.x = avatar.frame.width / 2 - nameLabel.frame.width / 2
                    
                    let positionOffset = min(
                        0,
                        UIScreen.main.bounds.width - nameLabel.convert(nameLabel.bounds.center, to: strongSelf.view).x - nameLabel.frame.width / 2 - 24
                    )
                                        
                    nameLabel.frame.origin.x += positionOffset
                    
                    nameBackground.frame.origin.x = nameLabel.frame.origin.x - 8
                    nameBackground.frame.origin.y = nameLabel.frame.origin.y - 4
                    nameBackground.frame.size = CGSize(width: nameLabel.frame.width + 16, height: nameLabel.frame.height + 8)
                    nameBackground.layer.cornerRadius = nameBackground.frame.height / 2
                }
                
                strongSelf.fastInlineShareView.peersCount = strongSelf.currentPeers.count
            }
        }
    }
    
    public init(
        accountContext: AccountContext, 
        presentationData: PresentationData,
        peers: [Peer],
        contextGesture: ContextGesture,
        sourceNode: ASDisplayNode,
        position: FastInlineShareView.Position,
        sourceFrame: @escaping () -> CGRect,
        sourceOrigin: @escaping () -> CGPoint,
        peerSelected: @escaping (Peer, UIView) -> Void
    ) {
        self.accountContext = accountContext
        self.presentationData = presentationData
        self.sourceFrame = sourceFrame
        self.contextGesture = contextGesture
        self.sourceNode = sourceNode
        self.sourceOrigin = sourceOrigin
        self.peerSelected = peerSelected
        
        self.style = FastInlineShareView.Style(position: position, peersCount: peers.count)

        self.fastInlineShareView = FastInlineShareView(style: style)
        super.init(navigationBarPresentationData: nil)

        DispatchQueue.main.async {
            self.currentPeers = self.style.position == .topLeft || self.style.position == .bottomLeft ? peers.reversed() : peers
        }
        
        contextGesture.activatedAfterCompletion = { [weak self]  _, _ in
            self?.finish()
        }
        
        contextGesture.addTarget(self, action: #selector(onGesture))
    }

    override public func viewDidLoad() {
        fastInlineShareView.frame = CGRect(x: sourceFrame().midX - 192 + 32, y: sourceFrame().midY - 192 + 32, width: 192, height: 192)
        
        var yOffset: CGFloat = 0
        let additionalOffset: CGFloat = fastInlineShareView.peersCount == 5 ? 56 : 0
        if fastInlineShareView.style.position == .topLeft || fastInlineShareView.style.position == .topRight {
            yOffset = min(0, UIScreen.main.bounds.height - fastInlineShareView.frame.maxY - additionalOffset - UIApplication.shared.delegate!.window!!.safeAreaInsets.bottom - 16)
        } else {
            yOffset = -min(0, fastInlineShareView.frame.midY - additionalOffset / 2 - UIApplication.shared.delegate!.window!!.safeAreaInsets.top - 24 - 8)
        }
        fastInlineShareView.offset = CGPoint(
            x: min(0, UIScreen.main.bounds.width - fastInlineShareView.frame.maxX - 8),
            y: yOffset
        )
        
        view.addSubview(fastInlineShareView)

        let sourceOffset = style.offset(lenght: 192 - 48, angleOffset: CGFloat.pi / 4)

        UIView.animate(withDuration: 0.55 * fastInlineShareAnimationSpeed, delay: 0, usingSpringWithDamping: fastInlineShareAnimationSpring, initialSpringVelocity: 1, animations: {
            self.sourceNode.transform = CATransform3DScale(CATransform3DTranslate(CATransform3DIdentity, -sourceOffset.x, -sourceOffset.y, 0), 2, 2, 1)
        })

        UIView.animate(withDuration: 0.15 * fastInlineShareAnimationSpeed, delay: 0, options: .curveEaseInOut, animations: {
            self.sourceNode.alpha = 0.0
        })

    }
        
    private func distance(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        return CGFloat(sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2)))
    }
    
    @objc private func onGesture() {
        var newViewState: FastInlineShareView.State = .unselected
                
        switch contextGesture.state {
        case .changed:
            let lenght = calculateSelectedIndex()
            
            if let lenght = lenght {
                newViewState = .selected(lenght)
            }
            
            fastInlineShareView.state = newViewState
            
        case .began:
            break
            
        default:
            finish()

        }
    }
    
    private func finish() {
        guard !wasFinishStart else { return }
        wasFinishStart = true
        
        let selectedIndex = calculateSelectedIndex()
        
        if let selectedIndex = selectedIndex {
            peerSelected(currentPeers[selectedIndex], fastInlineShareView.avatars[selectedIndex].view)
        }

        fastInlineShareView.dismiss {
            self.dismiss(animated: false)
        }
        
        UIView.animate(withDuration: 0.3 * fastInlineShareAnimationSpeed, delay: 0, options: .curveEaseInOut) {
            self.sourceNode.transform = CATransform3DIdentity
        }
        
        UIView.animate(withDuration: 0.15 * fastInlineShareAnimationSpeed, delay: 0.15, options: .curveEaseInOut) {
            self.sourceNode.alpha = 1
        }
    }
    
    private func calculateSelectedIndex() -> Int? {
        let location = contextGesture.location(in: nil)

        return (0..<fastInlineShareView.avatars.count).map {
            ($0, distance(fastInlineShareView.avatars[$0].view.convert(CGPoint(x: 24, y: 24), to: nil), location))
        }.filter {
            $0.1 < 36
        }.sorted(by: {
            $0.1 < $1.1
        }).first?.0
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
