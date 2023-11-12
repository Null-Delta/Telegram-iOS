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

public extension UIView {
    var globalFrame: CGRect {
        return convert(bounds, to: nil)
    }
}

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

    private var lastOrigin: CGPoint = .zero
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
                        clipStyle: .round,
                        synchronousLoad: true,
                        displayDimensions: CGSize(width: 48, height: 48)
                    )

                    nameLabel.text = EnginePeer(strongSelf.currentPeers[index]).compactDisplayTitle
                    nameLabel.sizeToFit()
                    
                    nameLabel.frame.origin.y = 4
                    nameLabel.frame.origin.x = avatar.frame.width / 2 - nameLabel.frame.width / 2
                    
                    let positionOffset = min(
                        0,
                        UIScreen.main.bounds.width - nameLabel.convert(nameLabel.bounds.center, to: strongSelf.view).x - nameLabel.frame.width / 2 - 24
                    )
                    
                    print(nameLabel.convert(CGPoint.zero, to: strongSelf.view).x)
                    
                    nameLabel.frame.origin.x += positionOffset
                    
                    nameBackground.frame.origin.x = nameLabel.frame.origin.x - 8
                    nameBackground.frame.origin.y = nameLabel.frame.origin.y - 4
                    nameBackground.frame.size = CGSize(width: nameLabel.frame.width + 16, height: nameLabel.frame.height + 8)
                    nameBackground.layer.cornerRadius = nameBackground.frame.height / 2
                    nameBackground.update(size: nameBackground.frame.size, animator: ControlledTransition.init(duration: 0.01, curve: .linear, interactive: false).animator)
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
        
        let isTop = sourceFrame().center.y > UIScreen.main.bounds.height / 2
        let isLeft = sourceFrame().center.x > UIScreen.main.bounds.width / 2
        let style: FastInlineShareView.Style = isTop ? (isLeft ? .topLeft : .topRight) : (isLeft ? .bottomLeft : .bottomRight)
        self.style = style
        self.fastInlineShareView = FastInlineShareView(style: style, peersCount: peers.count)
        super.init(navigationBarPresentationData: nil)

        DispatchQueue.main.async {
            self.currentPeers = peers
        }

        contextGesture.addTarget(self, action: #selector(onGesture))
    }

    override public func viewDidLoad() {
        fastInlineShareView.frame = CGRect(x: sourceFrame().midX - 192 + 32, y: sourceFrame().midY - 192 + 32, width: 192, height: 192)
        fastInlineShareView.xOffset = min(0, UIScreen.main.bounds.width - fastInlineShareView.frame.maxX - 8)
        
        view.addSubview(fastInlineShareView)

        self.sourceNode.view.transform = .identity
        lastOrigin = sourceOrigin()
        let sourceOffset = style.offset(lenght: 192 - 48, angleOffset: CGFloat.pi / 4)

        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 1, animations: {
            self.sourceNode.view.transform = .init(scaleX: 2, y: 2)
            self.sourceNode.frame.origin.x -= sourceOffset.x
            self.sourceNode.frame.origin.y -= sourceOffset.y
        })

        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseInOut, animations: {
            self.sourceNode.alpha = 0
        }, completion: { isFinish in
            if isFinish {
                self.wasOpenAnimationFinished = true
                self.sourceNode.isHidden = true
                self.sourceNode.frame.origin.x += sourceOffset.x
                self.sourceNode.frame.origin.y += sourceOffset.y
            }
        })

    }
        
    private func distance(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        return CGFloat(sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2)))
    }
    
    @objc private func onGesture() {
        let location = contextGesture.location(in: nil)
        var newViewState: FastInlineShareView.State = .unselected
                
        switch contextGesture.state {
        case .changed:
            let lenghts = (0..<fastInlineShareView.avatars.count).map {
                ($0, distance(fastInlineShareView.avatars[$0].view.convert(CGPoint(x: 24, y: 24), to: nil), location))
            }.filter {
                $0.1 < 36
            }.sorted(by: {
                $0.1 < $1.1
            })
            
            if !lenghts.isEmpty {
                newViewState = .selected(lenghts[0].0)
            }
            
            fastInlineShareView.state = newViewState
        case .ended, .cancelled, .failed:
            let selectedIndex = (0..<fastInlineShareView.avatars.count).map {
                ($0, distance(fastInlineShareView.avatars[$0].view.convert(CGPoint(x: 24, y: 24), to: nil), location))
            }.filter {
                $0.1 < 36
            }.sorted(by: {
                $0.1 < $1.1
            }).first?.0
            
            if let selectedIndex = selectedIndex {
                peerSelected(currentPeers[selectedIndex], fastInlineShareView.avatars[selectedIndex].view)
            }

            fastInlineShareView.dismiss {
                self.dismiss(animated: false)
            }
            
            self.sourceNode.pop_removeAllAnimations()
            self.sourceNode.isHidden = false
            self.sourceNode.alpha = 0
            
            let sourceOffset = style.offset(lenght: 192 - 48, angleOffset: CGFloat.pi / 4)

            self.sourceNode.view.transform = .init(scaleX: 2, y: 2)

            if wasOpenAnimationFinished {
                self.sourceNode.frame.origin.x -= sourceOffset.x
                self.sourceNode.frame.origin.y -= sourceOffset.y
            } else {
                self.sourceNode.frame.origin = lastOrigin
                self.sourceNode.frame.origin.x -= sourceOffset.x
                self.sourceNode.frame.origin.y -= sourceOffset.y
            }

            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                self.sourceNode.view.transform = .identity
                self.sourceNode.frame.origin.x += sourceOffset.x
                self.sourceNode.frame.origin.y += sourceOffset.y
            }
            
            UIView.animate(withDuration: 0.15, delay: 0.15, options: .curveEaseInOut) {
                self.sourceNode.alpha = 1
            }

        default:
            break
        }
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
