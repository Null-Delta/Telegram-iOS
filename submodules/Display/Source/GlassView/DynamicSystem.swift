//
//  DynamicSystem.swift
//  Telegram
//
//  Created by Rustam Khakhuk on 25.12.2025.
//

import Foundation
import UIKit

public class DynamicSystem {
    private let k1: CGFloat
    private let k2: CGFloat
    private let k3: CGFloat

    public private(set) var y: CGFloat
    public private(set) var yVelocity: CGFloat
    private var yBoost: CGFloat

    private var xNext: CGFloat
    public private(set) var x: CGFloat
    private var xVelocity: CGFloat

    private lazy var displayLink = CADisplayLink(target: self, selector: #selector(step))
    private var lastTime = Date().timeIntervalSince1970

    private var stepCallback: () -> Void

    deinit {
        displayLink.invalidate()
    }

    public init(f: CGFloat, z: CGFloat, r: CGFloat, stepCallback: @escaping () -> Void) {
        y = 0
        x = 0
        xNext = 0

        yVelocity = 0
        xVelocity = 0
        yBoost = 0

        k1 = z / (.pi * f)
        k2 = 1 / (pow(2 * .pi * f, 2))
        k3 = r * z / (2 * .pi * f)

        self.stepCallback = stepCallback

        if #available(iOS 15.0, *) {
            displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        }

        displayLink.add(to: .current, forMode: .common)
        displayLink.isPaused = true
    }

    public func start(value: CGFloat) {
        y = value
        x = value
        xNext = value

        yVelocity = 0
        xVelocity = 0
        yBoost = 0

        lastTime = Date().timeIntervalSince1970
        displayLink.isPaused = false
    }

    public func stop() {
        displayLink.isPaused = true
    }

    public func updateInput(x: CGFloat) {
        xNext = x
    }
   
    @objc private func step() {
        let deltaTime = min(0.02, Date().timeIntervalSince1970 - lastTime)
        lastTime = Date().timeIntervalSince1970

        print(deltaTime)

        xVelocity = (xNext - x) / deltaTime
        x = xNext

        yBoost = ((x + k3 * xVelocity - y - k1 * yVelocity) / k2)
        y += yVelocity * deltaTime
        yVelocity += yBoost * deltaTime

        stepCallback()
    }
}
