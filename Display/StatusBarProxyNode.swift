import Foundation
import AsyncDisplayKit

public enum StatusBarStyle {
    case Black
    case White
}

private enum StatusBarItemType {
    case Generic
    case Battery
}

func makeStatusBarProxy(style: StatusBarStyle) -> StatusBarProxyNode {
    return StatusBarProxyNode(style: style)
}

private class StatusBarItemNode: ASDisplayNode {
    var style: StatusBarStyle
    var targetView: UIView
    
    init(style: StatusBarStyle, targetView: UIView) {
        self.style = style
        self.targetView = targetView
        
        super.init()
    }
    
    func update() {
        let context = DrawingContext(size: self.targetView.frame.size, clear: true)
        
        if let contents = self.targetView.layer.contents where (self.targetView.layer.sublayers?.count ?? 0) == 0 && CFGetTypeID(contents) == CGImageGetTypeID() && false {
            let image = contents as! CGImageRef
            context.withFlippedContext { c in
                CGContextSetAlpha(c, CGFloat(self.targetView.layer.opacity))
                CGContextDrawImage(c, CGRect(origin: CGPoint(), size: context.size), image)
                CGContextSetAlpha(c, 1.0)
            }
            
            if let sublayers = self.targetView.layer.sublayers {
                for sublayer in sublayers {
                    let origin = sublayer.frame.origin
                    if let contents = sublayer.contents where CFGetTypeID(contents) == CGImageGetTypeID() {
                        let image = contents as! CGImageRef
                        context.withFlippedContext { c in
                            CGContextTranslateCTM(c, origin.x, origin.y)
                            CGContextDrawImage(c, CGRect(origin: CGPoint(), size: context.size), image)
                            CGContextTranslateCTM(c, -origin.x, -origin.y)
                        }
                    } else {
                        context.withContext { c in
                            UIGraphicsPushContext(c)
                            CGContextTranslateCTM(c, origin.x, origin.y)
                            sublayer.renderInContext(c)
                            CGContextTranslateCTM(c, -origin.x, -origin.y)
                            UIGraphicsPopContext()
                        }
                    }
                }
            }
        } else {
            context.withContext { c in
                UIGraphicsPushContext(c)
                self.targetView.layer.renderInContext(c)
                UIGraphicsPopContext()
            }
        }
        
        let type: StatusBarItemType = self.targetView.isKindOfClass(batteryItemClass!) ? .Battery : .Generic
        tintStatusBarItem(context, type: type, style: style)
        self.contents = context.generateImage()?.CGImage
        
        self.frame = self.targetView.frame
    }
}

private func tintStatusBarItem(context: DrawingContext, type: StatusBarItemType, style: StatusBarStyle) {
    switch type {
        case .Battery:
            let minY = 0
            let minX = 0
            let maxY = Int(context.size.height * context.scale)
            let maxX = Int(context.size.width * context.scale)
            if minY < maxY && minX < maxX {
                let basePixel = UnsafeMutablePointer<UInt32>(context.bytes)
                let pixelsPerRow = context.bytesPerRow / 4
                
                let midX = (maxX + minX) / 2
                let midY = (maxY + minY) / 2
                let baseMidRow = basePixel + pixelsPerRow * midY
                var baseX = minX
                while baseX < maxX {
                    let pixel = baseMidRow + baseX
                    let alpha = pixel.memory & 0xff000000
                    if alpha != 0 {
                        break
                    }
                    baseX += 1
                }
                
                baseX += 2
                
                var targetX = baseX
                while targetX < maxX {
                    let pixel = baseMidRow + targetX
                    let alpha = pixel.memory & 0xff000000
                    if alpha == 0 {
                        break
                    }
                    
                    targetX += 1
                }
                
                let batteryColor = (baseMidRow + baseX).memory
                let batteryR = (batteryColor >> 16) & 0xff
                let batteryG = (batteryColor >> 8) & 0xff
                let batteryB = batteryColor & 0xff
                
                var baseY = minY
                while baseY < maxY {
                    let baseRow = basePixel + pixelsPerRow * baseY
                    let pixel = baseRow + midX
                    let alpha = pixel.memory & 0xff000000
                    if alpha != 0 {
                        break
                    }
                    baseY += 1
                }
                
                var targetY = maxY - 1
                while targetY >= baseY {
                    let baseRow = basePixel + pixelsPerRow * targetY
                    let pixel = baseRow + midX
                    let alpha = pixel.memory & 0xff000000
                    if alpha != 0 {
                        break
                    }
                    targetY -= 1
                }
                
                targetY -= 1
                
                let baseColor: UInt32
                switch style {
                    case .Black:
                        baseColor = 0x000000
                    case .White:
                        baseColor = 0xffffff
                }
                
                let baseR = (baseColor >> 16) & 0xff
                let baseG = (baseColor >> 8) & 0xff
                let baseB = baseColor & 0xff
                
                var pixel = UnsafeMutablePointer<UInt32>(context.bytes)
                let end = UnsafeMutablePointer<UInt32>(context.bytes + context.length)
                while pixel != end {
                    let alpha = (pixel.memory & 0xff000000) >> 24
                    
                    let r = (baseR * alpha) / 255
                    let g = (baseG * alpha) / 255
                    let b = (baseB * alpha) / 255
                    
                    pixel.memory = (alpha << 24) | (r << 16) | (g << 8) | b
                    
                    pixel += 1
                }
                
                if batteryColor != 0xffffffff && batteryColor != 0xff000000 {
                    var y = baseY + 2
                    while y < targetY {
                        let baseRow = basePixel + pixelsPerRow * y
                        var x = baseX
                        while x < targetX {
                            let pixel = baseRow + x
                            let alpha = (pixel.memory >> 24) & 0xff
                            
                            let r = (batteryR * alpha) / 255
                            let g = (batteryG * alpha) / 255
                            let b = (batteryB * alpha) / 255
                            
                            pixel.memory = (alpha << 24) | (r << 16) | (g << 8) | b
                            
                            x += 1
                        }
                        y += 1
                    }
                }
            }
    case .Generic:
        var pixel = UnsafeMutablePointer<UInt32>(context.bytes)
        let end = UnsafeMutablePointer<UInt32>(context.bytes + context.length)
        
        let baseColor: UInt32
        switch style {
        case .Black:
            baseColor = 0x000000
        case .White:
            baseColor = 0xffffff
        }
        
        let baseR = (baseColor >> 16) & 0xff
        let baseG = (baseColor >> 8) & 0xff
        let baseB = baseColor & 0xff
        
        while pixel != end {
            let alpha = (pixel.memory & 0xff000000) >> 24
            
            let r = (baseR * alpha) / 255
            let g = (baseG * alpha) / 255
            let b = (baseB * alpha) / 255
            
            pixel.memory = (alpha << 24) | (r << 16) | (g << 8) | b
            
            pixel += 1
        }
    }
}

private let batteryItemClass: AnyClass? = NSClassFromString("UIStatusBarBatteryItemView")

private class StatusBarProxyNodeTimerTarget: NSObject {
    let action: () -> Void
    
    init(action: () -> Void) {
        self.action = action
    }
    
    @objc func tick() {
        action()
    }
}

class StatusBarProxyNode: ASDisplayNode {
    var timer: NSTimer?
    var style: StatusBarStyle {
        didSet {
            if oldValue != self.style {
                if !self.hidden {
                    self.updateItems()
                }
            }
        }
    }
    
    private var itemNodes: [StatusBarItemNode] = []
    
    override var hidden: Bool {
        get {
            return super.hidden
        } set(value) {
            if super.hidden != value {
                super.hidden = value
                
                if !value {
                    self.updateItems()
                    self.timer = NSTimer(timeInterval: 5.0, target: StatusBarProxyNodeTimerTarget { [weak self] in
                        self?.updateItems()
                        }, selector: #selector(StatusBarProxyNodeTimerTarget.tick), userInfo: nil, repeats: true)
                    NSRunLoop.mainRunLoop().addTimer(self.timer!, forMode: NSRunLoopCommonModes)
                } else {
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
        }
    }
    
    init(style: StatusBarStyle) {
        self.style = style
        
        super.init()
        
        self.hidden = true
        
        self.clipsToBounds = true
        //self.backgroundColor = UIColor.blueColor().colorWithAlphaComponent(0.2)
        
        let statusBar = StatusBarUtils.statusBar()!
        
        for subview in statusBar.subviews {
            let itemNode = StatusBarItemNode(style: style, targetView: subview)
            self.itemNodes.append(itemNode)
            self.addSubnode(itemNode)
        }
        
        self.frame = statusBar.bounds
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    private func updateItems() {
        let statusBar = StatusBarUtils.statusBar()!
        
        var i = 0
        while i < self.itemNodes.count {
            var found = false
            for subview in statusBar.subviews {
                if self.itemNodes[i].targetView == subview {
                    found = true
                    break
                }
            }
            if !found {
                self.itemNodes[i].removeFromSupernode()
                self.itemNodes.removeAtIndex(i)
            } else {
                self.itemNodes[i].style = self.style
                self.itemNodes[i].update()
                i += 1
            }
        }
        
        for subview in statusBar.subviews {
            var found = false
            for itemNode in self.itemNodes {
                if itemNode.targetView == subview {
                    found = true
                    break
                }
            }
            
            if !found {
                let itemNode = StatusBarItemNode(style: self.style, targetView: subview)
                itemNode.update()
                self.itemNodes.append(itemNode)
                self.addSubnode(itemNode)
            }
        }
    }
}
