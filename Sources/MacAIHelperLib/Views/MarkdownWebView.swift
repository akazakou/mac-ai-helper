// MarkdownWebView.swift
// Shows a Markdown answer in a web view. Unlike SwiftUI text, which selects inside one
// paragraph only, a web view lets the mouse select across the whole answer.

import AppKit
import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: MarkdownCopyScript.source, injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        // WKWebView has no public API for a transparent background on macOS;
        // without this the answer sits on a white page instead of the popup background.
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedMarkdown != markdown else { return }
        context.coordinator.loadedMarkdown = markdown
        webView.loadHTMLString(MarkdownHTMLRenderer.page(for: markdown), baseURL: nil)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        /// Link schemes handed over to the system; links come from untrusted AI output
        private static let externalLinkSchemes: Set<String> = ["http", "https", "mailto"]

        /// Markdown currently shown, so that unrelated SwiftUI updates do not reload the page
        var loadedMarkdown: String?

        /// Opens clicked links in the default app instead of navigating inside the popup.
        func webView(
            _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .linkActivated else { return .allow }
            if let url = navigationAction.request.url,
                Self.externalLinkSchemes.contains(url.scheme?.lowercased() ?? "")
            {
                NSWorkspace.shared.open(url)
            }
            return .cancel
        }
    }
}
