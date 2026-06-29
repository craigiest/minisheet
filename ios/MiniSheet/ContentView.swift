import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        WebView()
            .ignoresSafeArea()
            .background(Color.black)
    }
}

struct WebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        hideFormAccessoryBar(on: webView)

        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "WebContent") {
            let directoryURL = indexURL.deletingLastPathComponent()
            webView.loadFileURL(indexURL, allowingReadAccessTo: directoryURL)
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // WKWebView's text inputs get a private "previous/next/Done" accessory
    // bar above the keyboard. There's no public API to disable it, so we
    // patch the private WKContentView class (found by walking the view
    // hierarchy) to report no accessory view.
    private func hideFormAccessoryBar(on webView: WKWebView) {
        guard let contentViewClass = NSClassFromString("WKContentView") else { return }

        let noAccessoryViewSelector = #selector(getter: UIResponder.inputAccessoryView)
        guard
            class_getInstanceMethod(contentViewClass, noAccessoryViewSelector) != nil
        else { return }

        let dummyClassName = "MiniSheetWKContentViewNoAccessory"
        var patchedClass: AnyClass? = NSClassFromString(dummyClassName)

        if patchedClass == nil {
            guard let newClass = objc_allocateClassPair(contentViewClass, dummyClassName, 0) else { return }
            let block: @convention(block) (AnyObject) -> UIView? = { _ in nil }
            let implementation = imp_implementationWithBlock(block)
            class_addMethod(newClass, noAccessoryViewSelector, implementation, "@@:")
            objc_registerClassPair(newClass)
            patchedClass = newClass
        }

        guard let patchedClass else { return }

        // The content view doesn't exist until after the first layout pass,
        // so poll briefly until it shows up, then swap in the patched class.
        func attemptPatch(retriesRemaining: Int) {
            guard retriesRemaining > 0 else { return }
            guard let contentView = findSubview(of: contentViewClass, in: webView) else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    attemptPatch(retriesRemaining: retriesRemaining - 1)
                }
                return
            }
            object_setClass(contentView, patchedClass)
        }

        attemptPatch(retriesRemaining: 20)
    }

    private func findSubview(of targetClass: AnyClass, in view: UIView) -> UIView? {
        if view.isMember(of: targetClass) {
            return view
        }
        for subview in view.subviews {
            if let match = findSubview(of: targetClass, in: subview) {
                return match
            }
        }
        return nil
    }
}
