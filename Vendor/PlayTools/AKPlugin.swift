//
//  MacPlugin.swift
//  AKInterface
//
//  Created by Isaac Marovitz on 13/09/2022.
//

import AppKit
import CoreGraphics
import Foundation

class AKPlugin: NSObject, Plugin {
    required override init() {
        super.init()
        AKPlugin.setupScrollAxisSwapIfNeeded()
    }

    // Minecraft Bedrock reads mouse scroll through the GameController GCMouse
    // path, where the Catalyst translation delivers wheel deltas on the wrong
    // axis (vertical wheel input does nothing; horizontal input scrolls
    // vertically). Swap the axes at the AppKit layer, before Catalyst sees
    // the event, so vertical wheel scrolling reaches the game as vertical.
    private static var scrollSwapInstalled = false
    private static func setupScrollAxisSwapIfNeeded() {
        guard !scrollSwapInstalled,
              Bundle.main.bundleIdentifier == "com.mojang.minecraftpe" else { return }
        scrollSwapInstalled = true
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { event in
            guard let cgEvent = event.cgEvent?.copy() else { return event }
            let line1 = cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let line2 = cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            let point1 = cgEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
            let point2 = cgEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
            let fixed1 = cgEvent.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
            let fixed2 = cgEvent.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
            cgEvent.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: line2)
            cgEvent.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: line1)
            cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: point2)
            cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: point1)
            cgEvent.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: fixed2)
            cgEvent.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: fixed1)
            return NSEvent(cgEvent: cgEvent) ?? event
        })
    }

    var screenCount: Int {
        NSScreen.screens.count
    }

    var mousePoint: CGPoint {
        NSApplication.shared.windows.first?.mouseLocationOutsideOfEventStream ?? CGPoint()
    }

    var windowFrame: CGRect {
        NSApplication.shared.windows.first?.frame ?? CGRect()
    }

    var isMainScreenEqualToFirst: Bool {
        return NSScreen.main == NSScreen.screens.first
    }

    var mainScreenFrame: CGRect {
        return NSScreen.main!.frame as CGRect
    }

    var isFullscreen: Bool {
        NSApplication.shared.windows.first!.styleMask.contains(.fullScreen)
    }

    var cmdPressed: Bool = false
    var cursorHideLevel = 0
    func hideCursor() {
        NSCursor.hide()
        cursorHideLevel += 1
        CGAssociateMouseAndMouseCursorPosition(0)
        warpCursor()
    }

    func warpCursor() {
        guard let firstScreen = NSScreen.screens.first else {return}
        let frame = windowFrame
        // Convert from NS coordinates to CG coordinates
        CGWarpMouseCursorPosition(CGPoint(x: frame.midX, y: firstScreen.frame.height - frame.midY))
    }

    func unhideCursor() {
        NSCursor.unhide()
        cursorHideLevel -= 1
        if cursorHideLevel <= 0 {
            CGAssociateMouseAndMouseCursorPosition(1)
        }
    }

    func terminateApplication() {
        NSApplication.shared.terminate(self)
    }

    private var modifierFlag: UInt = 0
    func setupKeyboard(keyboard: @escaping(UInt16, Bool, Bool, Bool) -> Bool,
                       swapMode: @escaping() -> Bool) {
        func checkCmd(modifier: NSEvent.ModifierFlags) -> Bool {
            if modifier.contains(.command) {
                self.cmdPressed = true
                return true
            } else if self.cmdPressed {
                self.cmdPressed = false
            }
            return false
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            if checkCmd(modifier: event.modifierFlags) {
                return event
            }
            keyboard(event.keyCode, true, event.isARepeat,
                     event.modifierFlags.contains(.control))
            return nil
        })
        NSEvent.addLocalMonitorForEvents(matching: .keyUp, handler: { event in
            if checkCmd(modifier: event.modifierFlags) {
                return event
            }
            keyboard(event.keyCode, false, false,
                     event.modifierFlags.contains(.control))
            return nil
        })
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
            if checkCmd(modifier: event.modifierFlags) {
                return event
            }
            let pressed = self.modifierFlag < event.modifierFlags.rawValue
            let changed = self.modifierFlag ^ event.modifierFlags.rawValue
            self.modifierFlag = event.modifierFlags.rawValue
            let changedFlags = NSEvent.ModifierFlags(rawValue: changed)
            if pressed && changedFlags.contains(.option) {
                if swapMode() {
                    return nil
                }
                return nil
            }
            keyboard(event.keyCode, pressed, false,
                     event.modifierFlags.contains(.control))
            return nil
        })
    }

    func setupMouseMoved(_ mouseMoved: @escaping(CGFloat, CGFloat) -> Bool) {
        let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .otherMouseDragged, .rightMouseDragged]
        NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            let consumed = mouseMoved(event.deltaX, event.deltaY)
            if consumed {
                return nil
            }
            return event
        })
        // transpass mouse moved event when no button pressed, for traffic light button to light up
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { event in
            _ = mouseMoved(event.deltaX, event.deltaY)
            return event
        })
    }

    func setupMouseButton(left: Bool, right: Bool, _ consumed: @escaping(Int, Bool) -> Bool) {
        let downType: NSEvent.EventTypeMask = left ? .leftMouseDown : right ? .rightMouseDown : .otherMouseDown
        let upType: NSEvent.EventTypeMask = left ? .leftMouseUp : right ? .rightMouseUp : .otherMouseUp
        NSEvent.addLocalMonitorForEvents(matching: downType, handler: { event in
            // For traffic light buttons when fullscreen
            if event.window != NSApplication.shared.windows.first! {
                return event
            }
            if consumed(event.buttonNumber, true) {
                return nil
            }
            return event
        })
        NSEvent.addLocalMonitorForEvents(matching: upType, handler: { event in
            if consumed(event.buttonNumber, false) {
                return nil
            }
            return event
        })
    }

    func setupScrollWheel(_ onMoved: @escaping(CGFloat, CGFloat) -> Bool) {
        NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.scrollWheel, handler: { event in
            var deltaX = event.scrollingDeltaX, deltaY = event.scrollingDeltaY
            if !event.hasPreciseScrollingDeltas {
                deltaX *= 16
                deltaY *= 16
            }
            let consumed = onMoved(deltaX, deltaY)
            if consumed {
                return nil
            }
            return event
        })
    }

    func urlForApplicationWithBundleIdentifier(_ value: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: value)
    }

    func setMenuBarVisible(_ visible: Bool) {
        NSMenu.setMenuBarVisible(visible)
    }
}
