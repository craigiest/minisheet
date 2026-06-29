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
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "exportCsv")
        // WKWebView blocks JS clipboard access and native "Paste" menu/Cmd+V
        // events by default; Safari enables these internally but a bare
        // WKWebView doesn't. Without this, full.html's paste buttons fall
        // back to a manual prompt and the system Paste menu does nothing.
        configuration.preferences.setValue(true, forKey: "javaScriptCanAccessClipboard")
        configuration.preferences.setValue(true, forKey: "DOMPasteAllowed")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.navigationDelegate = context.coordinator
        hideFormAccessoryBar(on: webView)

        if let indexURL = Bundle.main.url(forResource: "full", withExtension: "html", subdirectory: "WebContent") {
            let directoryURL = indexURL.deletingLastPathComponent()
            webView.loadFileURL(indexURL, allowingReadAccessTo: directoryURL)
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // The web app's CSV export normally uses a blob: URL + <a download>
    // click (or navigator.share), neither of which is reliable from a
    // file://-loaded WKWebView. When running in this app, full.html instead
    // posts the CSV content straight to this "exportCsv" message handler,
    // which writes it to a temp file and hands it to a "Save to Files"
    // document picker. The WKDownload plumbing below stays as a fallback
    // for any other downloads.
    final class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate, WKScriptMessageHandler, UIDocumentPickerDelegate {
        private var destinations: [ObjectIdentifier: URL] = [:]
        private var pendingExportURL: URL?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard
                message.name == "exportCsv",
                let body = message.body as? [String: Any],
                let filename = body["filename"] as? String,
                let content = body["content"] as? String
            else { return }

            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: destination)

            do {
                try content.write(to: destination, atomically: true, encoding: .utf8)
                presentSaveToFiles(for: destination)
            } catch {
                NSLog("Failed to write exported CSV: \(error)")
            }
        }

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
                self.presentSaveToFiles(for: fileURL)
            }
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            destinations.removeValue(forKey: ObjectIdentifier(download))
        }

        // Goes straight to the "Save to Files" picker instead of the general
        // share sheet, which on a CSV defaults to unrelated suggestions
        // (Notes, Reminders, Mail) and buries the actually-useful "Save to
        // Files" option several scrolls down.
        private func presentSaveToFiles(for fileURL: URL) {
            guard let rootViewController = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?.rootViewController
            else { return }

            var presenter = rootViewController
            while let presented = presenter.presentedViewController {
                presenter = presented
            }

            pendingExportURL = fileURL
            let documentPicker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
            documentPicker.delegate = self
            presenter.present(documentPicker, animated: true)
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            cleanUpPendingExport()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            cleanUpPendingExport()
        }

        private func cleanUpPendingExport() {
            guard let url = pendingExportURL else { return }
            pendingExportURL = nil
            try? FileManager.default.removeItem(at: url)
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
