// MarkdownHTMLRenderer.swift
// Turns a Markdown answer into a self-contained HTML page for MarkdownWebView.

import AppKit
import cmark_gfm
import cmark_gfm_extensions

enum MarkdownHTMLRenderer {
    /// GitHub Flavored Markdown syntax added on top of CommonMark
    private static let syntaxExtensionNames = ["autolink", "strikethrough", "tasklist", "table"]

    /// The answer is untrusted text, so the page may not load anything or run its own scripts.
    private static let contentSecurityPolicy = "default-src 'none'; style-src 'unsafe-inline'"

    /// Returns the full HTML page that shows the Markdown text.
    static func page(for markdown: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="\(contentSecurityPolicy)">
        <style>\(styleSheet)</style>
        </head>
        <body>\(html(for: markdown))</body>
        </html>
        """
    }

    /// Converts Markdown to an HTML fragment. cmark runs in its default safe mode,
    /// which drops raw HTML and unsafe link schemes found in the text.
    static func html(for markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()

        let parser = cmark_parser_new(CMARK_OPT_DEFAULT)
        defer { cmark_parser_free(parser) }
        for name in syntaxExtensionNames {
            if let syntaxExtension = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, syntaxExtension)
            }
        }
        cmark_parser_feed(parser, markdown, markdown.utf8.count)

        guard let document = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(document) }

        let syntaxExtensions = cmark_parser_get_syntax_extensions(parser)
        guard let html = cmark_render_html(document, CMARK_OPT_DEFAULT, syntaxExtensions) else {
            return ""
        }
        defer { free(html) }
        return String(cString: html)
    }

    /// GitHub-like look that follows the light or dark appearance of the popup.
    private static let styleSheet = """
        :root { color-scheme: light dark; }
        body {
            font: \(Int(NSFont.systemFontSize))px/1.5 -apple-system, sans-serif;
            margin: 12px;
            overflow-wrap: break-word;
        }
        body > :first-child { margin-top: 0; }
        body > :last-child { margin-bottom: 0; }
        h1, h2, h3, h4, h5, h6 { margin: 1.2em 0 0.6em; line-height: 1.25; }
        h1 { font-size: 2em; }
        h2 { font-size: 1.5em; }
        h3 { font-size: 1.25em; }
        h4, h5, h6 { font-size: 1em; }
        h1, h2 { padding-bottom: 0.3em; border-bottom: 1px solid rgba(127, 127, 127, 0.3); }
        p, ul, ol, pre, table, blockquote { margin: 0 0 1em; }
        li > ul, li > ol { margin-bottom: 0; }
        ul, ol { padding-left: 2em; }
        li:has(> input[type="checkbox"]) { list-style: none; }
        li > input[type="checkbox"] { margin: 0 0.3em 0 -1.4em; }
        code, pre { font-family: ui-monospace, Menlo, monospace; font-size: 0.92em; }
        code { padding: 0.15em 0.35em; border-radius: 4px; background: rgba(127, 127, 127, 0.18); }
        pre { padding: 10px; border-radius: 6px; overflow-x: auto; background: rgba(127, 127, 127, 0.15); }
        pre code { padding: 0; background: none; font-size: 1em; }
        blockquote { padding-left: 1em; border-left: 3px solid rgba(127, 127, 127, 0.4); opacity: 0.8; }
        table { border-collapse: collapse; }
        th, td { padding: 4px 10px; border: 1px solid rgba(127, 127, 127, 0.35); }
        hr { border: 0; border-top: 1px solid rgba(127, 127, 127, 0.35); }
        """
}
