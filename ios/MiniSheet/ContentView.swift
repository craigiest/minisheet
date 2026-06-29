import SwiftUI
import UIKit
import WebKit

struct ContentView: View {
    var body: some View {
        WebView()
            .ignoresSafeArea()
            .background(Color.black)
    }
}

struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.navigationDelegate = context.coordinator
        hideFormAccessoryBar(on: webView)

        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "WebContent") {
            let directoryURL = indexURL.deletingLastPathComponent()
            webView.loadFileURL(indexURL, allowingReadAccessTo: directoryURL)
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // The web app exports CSVs via a blob: URL + <a download> click, which
    // WKWebView can't save on its own — it has to be handed off natively as
    // a WKDownload and then shared out via the share sheet (e.g. to Files).
    final class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
        private var destinations: [ObjectIdentifier: URL] = [:]

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        func download(
            _ download: WKDownload,
            decideDestinationUsing response: URLResponse,
            suggestedFilename: String,
            completionHandler: @escaping (URL?) -> Void
        ) {
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedFilename)
            try? FileManager.default.removeItem(at: destination)
            destinations[ObjectIdentifier(download)] = destination
            completionHandler(destination)
        }

        func downloadDidFinish(_ download: WKDownload) {
            guard let fileURL = destinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
            DispatchQueue.main.async {
                Coordinator.presentShareSheet(for: fileURL)
            }
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            destinations.removeValue(forKey: ObjectIdentifier(download))
        }

        private static func presentShareSheet(for fileURL: URL) {
            guard let rootViewController = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?.rootViewController
            else { return }

            var presenter = rootViewController
            while let presented = presenter.presentedViewController {
                presenter = presented
            }

            let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            presenter.present(activityViewController, animated: true)
        }
    }

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
