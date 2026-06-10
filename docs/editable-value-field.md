# Editable Value Field Pattern

SwiftUI gestures (onTapGesture, TapGesture, @FocusState) are unreliable on macOS for implementing double-click-to-edit behavior on Text views. Use NSViewRepresentable with an NSTextField subclass instead.

## Implementation

1. Subclass NSTextField and override mouseDown to detect double-click:

```swift
class ClickableTextField: NSTextField {
    var onDoubleClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        super.mouseDown(with: event)
    }
}
```

2. Create NSViewRepresentable wrapping the custom NSTextField:

```swift
struct EditableValueField: NSViewRepresentable {
    let text: String
    let onCommit: (String) -> Void

    func makeNSView(context: Context) -> ClickableTextField { ... }
    func updateNSView(_ nsView: ClickableTextField, context: Context) { ... }
    func makeCoordinator() -> Coordinator { ... }
}
```

3. Coordinator manages edit state and click-to-dismiss:

```swift
class Coordinator: NSObject, NSTextFieldDelegate {
    var isEditing = false
    private var clickMonitor: Any?

    func beginEditing(_ tf: NSTextField) {
        tf.isEditable = true
        tf.isSelectable = true
        tf.window?.makeFirstResponder(tf)
        // Select all text
        DispatchQueue.main.async {
            (tf.currentEditor() as? NSTextView)?.selectAll(nil)
        }
        // Monitor clicks to dismiss
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            DispatchQueue.main.async { self?.endEditing(from: tf) }
            return event
        }
    }

    func endEditing(from tf: NSTextField?) {
        isEditing = false
        NSEvent.removeMonitor(clickMonitor!)
        clickMonitor = nil
        tf?.isEditable = false
        tf?.isSelectable = false
        tf?.window?.makeFirstResponder(nil)
        onCommit(tf?.stringValue ?? "")
    }
}
```

4. Constrain width in SwiftUI with .frame(width: 50).

## Key points

- Do NOT use SwiftUI gestures (onTapGesture, TapGesture, @FocusState, .focused()) for this pattern on macOS. They fail silently.
- Use NSTextField.isEditable toggle instead of replacing Text with TextField. This avoids height changes.
- Use NSTextField.isBordered = false and drawsBackground = false for seamless appearance.
- Use NSEvent.addLocalMonitorForEvents for click-to-dismiss. Remove the monitor after use.
- Double-click detection uses AppKit's native event.clickCount, not SwiftUI TapGesture(count: 2).
