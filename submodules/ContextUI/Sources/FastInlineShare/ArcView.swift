//
//  ArcView.swift
//  _LocalDebugOptions
//
//  Created by Rustam Khakhuk on 07.11.2023.
//

import Foundation
import UIKit

public final class ArcView: UIView {
    public var expandedRadius: CGFloat = 32.0
    public var arcOffset: CGFloat = 0
    public var arcCenter: CGPoint = .zero
    public var maxArcAngle: CGFloat = CGFloat.pi / 4
    
    lazy public var shapeLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        shapeLayer.frame = bounds
        shapeLayer.path = constructPath(
            shapeRadius: 15,
            angle: 0.001,
            radius: frame.width - expandedRadius,
            center: CGPoint(x: frame.width - expandedRadius, y: frame.height - expandedRadius)
        )
        shapeLayer.fillColor = UIColor.white.cgColor
        
        return shapeLayer
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.addSublayer(shapeLayer)
        arcCenter = CGPoint(x: frame.width - expandedRadius, y: frame.height - expandedRadius)
        transform = CGAffineTransform(translationX: (frame.width - expandedRadius) / sqrt(2), y: (frame.width - expandedRadius) / sqrt(2))
    }
    
    public func constructPath(
        shapeRadius: CGFloat,
        angle: CGFloat,
        radius: CGFloat,
        center: CGPoint
    ) -> CGPath {
        let beizerPath = UIBezierPath()
        
        let bottomCirclePosition = CGPoint(
            x: center.x + (radius - shapeRadius) * cos(5 / 4 * CGFloat.pi - angle + arcOffset),
            y: center.y + (radius - shapeRadius) * sin(5 / 4 * CGFloat.pi - angle + arcOffset)
        )

        let topCirclePosition = CGPoint(
            x: center.x + (radius - shapeRadius) * cos(5 / 4 * CGFloat.pi + angle + arcOffset),
            y: center.y + (radius - shapeRadius) * sin(5 / 4 * CGFloat.pi + angle + arcOffset)
        )
        
        let angleOffset = (CGFloat.pi / 4) * (1 - (angle / (CGFloat.pi / 4)))
        
        beizerPath.addArc(
            withCenter: center,
            radius: radius,
            startAngle: 5 / 4 * CGFloat.pi - angle + arcOffset,
            endAngle: 5 / 4 * CGFloat.pi + angle + arcOffset,
            clockwise: true
        )
        
        beizerPath.addArc(
            withCenter: topCirclePosition,
            radius: shapeRadius,
            startAngle: 1.5 * CGFloat.pi - angleOffset + arcOffset,
            endAngle: 0.5 * CGFloat.pi - angleOffset + arcOffset,
            clockwise: true
        )

        beizerPath.addArc(
            withCenter: center,
            radius: radius - shapeRadius * 2,
            startAngle: 5 / 4 * CGFloat.pi + angle + arcOffset,
            endAngle: 5 / 4 * CGFloat.pi - angle + arcOffset,
            clockwise: false
        )

        beizerPath.addArc(
            withCenter: bottomCirclePosition,
            radius: shapeRadius,
            startAngle: 2 * CGFloat.pi + angleOffset + arcOffset,
            endAngle: CGFloat.pi + angleOffset + arcOffset,
            clockwise: true
        )
        
        beizerPath.close()
        beizerPath.fill()
        
        return beizerPath.cgPath
    }
    
    public func animate(layer: CALayer, key: String = "path", isExpanded: Bool, completion: (() -> Void)? = nil) {
        var values: [CGPath] = []
        for i in 0..<120 {
            let progress = CGFloat(isExpanded ? i : 120 - i) / 120.0
            values.append(
                constructPath(
                    shapeRadius: 15 + (expandedRadius - 15) * progress,
                    angle: 0.001 + (maxArcAngle - 0.001) * progress,
                    radius: frame.width - expandedRadius,
                    center: arcCenter
                )
            )
        }
        
        let animation = CAKeyframeAnimation(keyPath: key)
        animation.values = values
        animation.duration = 0.3 * fastInlineShareAnimationSpeed
        animation.isRemovedOnCompletion = false
        animation.fillMode = .both
        animation.timingFunction = .some(.init(name: .easeInEaseOut))
        
        layer.add(animation, forKey: key)

        if isExpanded {
            self.alpha = 0
            
            transform = CGAffineTransform(
                translationX: -(frame.width - expandedRadius - 15) * cos(5 / 4 * CGFloat.pi + arcOffset),
                y: -(frame.width - expandedRadius - 15) * sin(5 / 4 * CGFloat.pi + arcOffset)
            )
            
            UIView.animate(withDuration: 0.55 * fastInlineShareAnimationSpeed, delay: 0, usingSpringWithDamping: fastInlineShareAnimationSpring, initialSpringVelocity: 1, animations: {
                self.transform = .identity
            }, completion: { _ in
                completion?()
            })
            
            UIView.animate(withDuration: 0.1 * fastInlineShareAnimationSpeed, delay: 0, options: .curveEaseOut) {
                self.alpha = 1
            }

        } else {
            transform = .identity
            self.alpha = 1
            
            UIView.animate(withDuration: 0.1 * fastInlineShareAnimationSpeed, delay: 0.15 * fastInlineShareAnimationSpeed, options: .curveEaseInOut) {
                self.alpha = 0
            }
            
            UIView.animate(withDuration: 0.3 * fastInlineShareAnimationSpeed, delay: 0, options: .curveEaseInOut, animations: {
                self.transform = CGAffineTransform(
                    translationX: -(self.frame.width - 47) * cos(5 / 4 * CGFloat.pi + self.arcOffset),
                    y: -(self.frame.width - 47) * sin(5 / 4 * CGFloat.pi + self.arcOffset)
                )
            }, completion: { _ in
                completion?()
            })
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
