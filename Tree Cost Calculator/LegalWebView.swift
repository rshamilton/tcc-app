//
//  LegalWebView.swift
//  Tree Cost Calculator
//
//  Created by Ryan Hamilton on 1/9/26.
//

import SwiftUI
import WebKit

struct LegalWebView: View {
    let title: String
    let resourceName: String

    var body: some View {
        WebView(resourceName: resourceName)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WebView: UIViewRepresentable {
    let resourceName: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        
        // Set background to system background color
        if #available(iOS 13.0, *) {
            webView.backgroundColor = UIColor.systemBackground
        } else {
            webView.backgroundColor = .white
        }
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "html", subdirectory: "Legal") else {
            let errorHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; padding: 24px; }
                    .error { color: #666; text-align: center; margin-top: 48px; }
                </style>
            </head>
            <body>
                <div class="error">
                    <p>Content could not be loaded</p>
                </div>
            </body>
            </html>
            """
            uiView.loadHTMLString(errorHTML, baseURL: nil)
            return
        }
        uiView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}

#Preview {
    NavigationView {
        LegalWebView(title: "Privacy Policy", resourceName: "privacy")
    }
}
