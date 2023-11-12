//
//  FastInlineShareNode.swift
//  _LocalDebugOptions
//
//  Created by Rustam Khakhuk on 07.11.2023.
//

import Foundation
import UIKit
import Display
import AvatarNode
import Postbox

public final class FastInlineShareBackground: UIView {
    private let backgroundBlur: UIVisualEffectView
    private let shadowBlur: UIVisualEffectView
    let backgroundMask: ArcView
    let shadowMask: ArcView
    let angleOffset: CGFloat
    private let style: FastInlineShareView.Style
    
    private var container: UIView = UIView()

    public init(frame: CGRect, style: FastInlineShareView.Style, peersCount: Int) {
        
        self.style = style
        self.angleOffset = style.arcAngleOffset
        backgroundBlur = UIVisualEffectView(frame: CGRect(x: -8, y: -8, width: 2 * 192 + 16, height: 2 * 192 + 16))
        shadowBlur = UIVisualEffectView(frame: CGRect(x: -8 - 196, y: -8 - 196, width: 4 * 192 + 16, height: 4 * 192 + 16))
        
        backgroundBlur.effect = UIBlurEffect(style: .regular)
        shadowBlur.effect = UIBlurEffect(style: .regular)
        
        backgroundMask = ArcView(frame: CGRect(x: 8, y: 8, width: 192, height: 192))
        shadowMask = ArcView(frame: CGRect(x: 196 - 48 - 8, y: 196 - 48 - 8, width: 192 + 128, height: 192 + 128))
        
        backgroundMask.arcOffset = angleOffset
        shadowMask.arcOffset = angleOffset
        
        super.init(frame: frame)

        shadowMask.expandedRadius = 96
        shadowMask.arcCenter = CGPoint(x: 224, y: 224)
        shadowMask.shapeLayer.opacity = 0
        
        shadowMask.layer.shadowColor = UIColor.black.cgColor
        shadowMask.layer.shadowRadius = 24
        shadowMask.layer.shadowOpacity = 1

        backgroundBlur.mask = backgroundMask
        shadowBlur.mask = shadowMask
        
        clearBlur(effect: backgroundBlur)
        clearBlur(effect: shadowBlur)
        
        container.frame = CGRect(x: 0, y: 0, width: 192, height: 192)
        
        container.layer.shadowRadius = 6
        container.layer.shadowOpacity = 0.15
        container.layer.shadowColor = UIColor.black.cgColor

        addSubview(shadowBlur)
        container.addSubview(backgroundBlur)
        addSubview(container)
        
        backgroundMask.maxArcAngle = peersCount == 4 ? CGFloat.pi / 4 : CGFloat.pi / 6
        shadowMask.maxArcAngle = peersCount == 4 ? CGFloat.pi / 4 : CGFloat.pi / 6
        
        backgroundMask.animate(layer: backgroundMask.shapeLayer, isExpanded: true)
        shadowMask.animate(layer: shadowMask.layer, key: "shadowPath", isExpanded: true)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func clearBlur(effect: UIVisualEffectView) {
        if let sublayer = effect.layer.sublayers?[0], let filters = sublayer.filters {
            sublayer.backgroundColor = nil
            sublayer.isOpaque = false
            
            let allowedKeys: [String] = [
                "gaussianBlur"
            ]
            sublayer.filters = filters.filter { filter in
                guard let filter = filter as? NSObject else {
                    return true
                }
                let filterName = String(describing: filter)
                if !allowedKeys.contains(filterName) {
                    return false
                }
                return true
            }
        }
    }
    
    public func hide(completion: @escaping () -> Void) {
        backgroundMask.animate(layer: backgroundMask.shapeLayer, isExpanded: false, completion: {
            completion()
        })
        
        let offset = style.offset(lenght: 64, angleOffset: CGFloat.pi / 4)
        shadowMask.animate(layer: shadowMask.layer, key: "shadowPath", isExpanded: false)
        UIView.animate(withDuration: 0.3) {
            self.shadowMask.frame.origin.x -= offset.x
            self.shadowMask.frame.origin.y -= offset.y
        }
    }
}

public final class FastInlineShareView: UIView {
    public enum State: Equatable {
        case selected(Int)
        case unselected
    }
    
    public enum Style {
        case topLeft, topRight, bottomLeft, bottomRight
        
        public var angle: CGFloat {
            switch self {
            case .topLeft:
                return 0
            case .topRight:
                return 1 / 2 * CGFloat.pi
            case .bottomLeft:
                return 3 / 2 * CGFloat.pi
            case .bottomRight:
                return CGFloat.pi
            }
        }
        
        public var arcAngleOffset: CGFloat {
            switch self {
            case .topLeft:
                return 0
            case .topRight:
                return Style.topLeft.arcAngleOffset + CGFloat.pi / 2
            case .bottomLeft:
                return Style.topLeft.arcAngleOffset + 3 / 2 * CGFloat.pi
            case .bottomRight:
                return Style.topLeft.arcAngleOffset + CGFloat.pi
            }
        }
        
        public func offset(lenght: CGFloat, angleOffset: CGFloat = 0) -> CGPoint {
            let angle = self.angle + angleOffset
            return CGPoint(
                x: lenght * cos(angle),
                y: lenght * sin(angle)
            )
        }
    }
    
    public private(set) var style: Style
    
    public var peersCount: Int = 3 {
        didSet {
            guard peersCount != oldValue else { return }
            updateView()
        }
    }
    
    public var state: State = .unselected {
        didSet {
            guard oldValue != state else { return }
            updateView()
        }
    }

    private let background: FastInlineShareBackground
    private(set) var avatars: [AvatarNode] = []
    private(set) var namesLabels: [UILabel] = []
    private(set) var peerContainers: [UIView] = []
    private(set) var namesBackgrounds: [BlurredBackgroundView] = []
    public var xOffset: CGFloat = 0 {
        didSet {
            UIView.animate(withDuration: 0.3) {
                self.frame.origin.x += self.xOffset
            }
        }
    }
    
    private let hapticFeedback = HapticFeedback()
    private let shadowBlurLayer = CAShapeLayer()
        
    public init(style: Style, peersCount: Int) {

        self.style = style
        self.peersCount = peersCount

        for _ in 0..<peersCount {
            avatars.append(AvatarNode(font: avatarPlaceholderFont(size: 19.0)))
            namesLabels.append(UILabel())
            peerContainers.append(UIView())

            namesBackgrounds.append(
                BlurredBackgroundView(color: UIColor.black.withAlphaComponent(0.33), enableBlur: true)
            )
        }
        
        background = FastInlineShareBackground(
            frame: .zero,
            style: style,
            peersCount: peersCount
        )
        
        super.init(frame: .zero)
        
        addSubview(background)
                
        let range: any Collection<Int> = ((style == .bottomRight || style == .topRight) ? (0..<peersCount) : (0..<peersCount).reversed())
        
        for i in range {
            addSubview(peerContainers[i])
            avatars[i].frame = CGRect(x: (192 - 32) - 24, y: (192 - 32) - 24, width: 48, height: 48)
            namesLabels[i].alpha = 0
            namesLabels[i].textColor = .white
            namesLabels[i].font = .systemFont(ofSize: 12, weight: .semibold)
            namesBackgrounds[i].alpha = 0
            namesBackgrounds[i].clipsToBounds = true
        }
        
        for i in 0..<peersCount {
            peerContainers[i].addSubview(namesBackgrounds[i])
            peerContainers[i].addSubview(namesLabels[i])
            peerContainers[i].addSubview(avatars[i].view)

            peerContainers[i].frame = CGRect(x: (192 - 32) - 24, y: (192 - 32) - 24, width: 48, height: 48 + 28)
            peerContainers[i].layer.anchorPoint = CGPoint(x: 0.5, y: 52.0 / 76.0)
            avatars[i].frame = CGRect(x: 0, y: 28, width: 48, height: 48)

        }
        
        for i in 0..<peersCount {
            var angle: CGFloat = 0
            if peersCount == 4 {
                angle = CGFloat(i) * CGFloat.pi / 6
            } else if peersCount == 3 {
                angle = CGFloat(i) * CGFloat.pi / 6 + (1 / 12 * CGFloat.pi)
            }
            
            var center = style.offset(lenght: 192 - 56 - 8, angleOffset: angle - CGFloat.pi).offsetBy(dx: 192 - 56, dy: 192 - 56)
            center.y -= 28

            self.peerContainers[i].transform = .init(scaleX: 0.1, y: 0.1)
            self.peerContainers[i].alpha = 0
            let needDelay = i == 0 || i == peersCount - 1
            UIView.animate(withDuration: 0.3, delay: needDelay ? 0.12 : 0, animations: {
                self.peerContainers[i].transform = .identity
                self.peerContainers[i].alpha = 1
            })
            
            UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 1, animations: {
                self.peerContainers[i].frame.origin = center
            })
        }
        
        hapticFeedback.impact(.medium)
    }
    
    private func updateView() {
        switch state {
        case .selected(let index):
            hapticFeedback.impact(.light)
            
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseInOut, animations: {
                for i in 0..<self.peersCount {
                    if i == index {
                        self.peerContainers[i].transform = .init(scaleX: 1.15, y: 1.15)

                        self.avatars[i].alpha = 1
                        self.namesLabels[i].alpha = 1
                        self.namesBackgrounds[i].alpha = 1
                    } else {
                        self.peerContainers[i].transform = .identity

                        self.avatars[i].alpha = 0.5
                        self.namesLabels[i].alpha = 0
                        self.namesBackgrounds[i].alpha = 0
                    }
                }
            })
        case .unselected:
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseInOut, animations: {
                for index in 0..<self.peersCount {
                    self.peerContainers[index].transform = .identity

                    self.avatars[index].alpha = 1
                    self.namesLabels[index].alpha = 0
                    self.namesBackgrounds[index].alpha = 0
                }
            })
        }
    }
    
    public func dismiss(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            for conrainers in self.peerContainers {
                conrainers.frame.origin = CGPoint(x: 192 - 32 - 24, y: 192 - 32 - 24 - 28)
                conrainers.alpha = 0
                conrainers.transform = .init(scaleX: 0.1, y: 0.1)
            }
        }

        background.hide(completion: completion)
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
