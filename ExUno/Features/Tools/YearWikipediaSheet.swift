import SwiftUI
import WebKit

struct WikipediaYearArticle: Identifiable {
    let year: Int
    let url: URL
    var id: String { url.absoluteString }

    init?(year: Int, language: LanguageCode) {
        guard (1...9999).contains(year) else { return nil }
        // Regional editions share Wikipedia's language edition.
        let edition = language.rawValue.split(separator: "-")[0]
        guard let url = URL(string: "https://\(edition).wikipedia.org/wiki/\(year)") else { return nil }
        self.year = year
        self.url = url
    }
}

struct YearWikipediaSheet: View {
    let article: WikipediaYearArticle
    @Environment(\.dismiss) private var dismiss
    @State private var loading = true
    @State private var failure: String?
    @State private var requestID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                if let failure {
                    ContentUnavailableView {
                        Label("Wikipedia unavailable", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(failure)
                    } actions: {
                        Button("Try again", action: retry)
                    }
                } else {
                    YearArticleWebView(url: article.url, loading: $loading, failure: $failure)
                        .id(requestID)
                    if loading { ProgressView().padding(16).background(.regularMaterial, in: Capsule()) }
                }
            }
            .navigationTitle("Wikipedia · \(String(article.year))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func retry() {
        loading = true
        failure = nil
        requestID = UUID()
    }
}

/// Created only by the learner opening the sheet; no prefetch or background requests.
private struct YearArticleWebView: UIViewRepresentable {
    let url: URL
    @Binding var loading: Bool
    @Binding var failure: String?

    func makeCoordinator() -> Coordinator { Coordinator(loading: $loading, failure: $failure) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.navigationDelegate = nil
        uiView.stopLoading()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var loading: Bool
        @Binding var failure: String?

        init(loading: Binding<Bool>, failure: Binding<String?>) {
            _loading = loading
            _failure = failure
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loading = false }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            failed(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            failed(error)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if navigationResponse.isForMainFrame,
               let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 {
                loading = false
                failure = response.statusCode == 404
                    ? "There is no article for this year in this Wikipedia edition yet."
                    : "Wikipedia could not load this article. Please try again later."
                decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }

        private func failed(_ error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            loading = false
            failure = "An internet connection is needed to read Wikipedia. Check your connection and try again. The year tool still works offline."
        }
    }
}
