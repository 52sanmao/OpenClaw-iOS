import SwiftUI

/// Renders markdown content using iOS 15+ AttributedString.
struct MarkdownText: View {
    let content: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: content, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )) {
            Text(attributed)
                .textSelection(.enabled)
        } else {
            Text(content)
                .textSelection(.enabled)
        }
    }
}

/// Renders full markdown with code blocks as separate styled views.
struct RichMarkdownView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    MarkdownText(content: text)
                        .font(.body)
                case .code(let lang, let code):
                    CodeBlockView(language: lang, code: code)
                }
            }
        }
    }

    private enum Block {
        case text(String)
        case code(String?, String)
    }

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        var remaining = content
        let codePattern = "```"

        while let startRange = remaining.range(of: codePattern) {
            // Text before code block
            let textBefore = String(remaining[remaining.startIndex..<startRange.lowerBound])
            if !textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.text(textBefore))
            }

            remaining = String(remaining[startRange.upperBound...])

            // Extract language hint (first line)
            var lang: String? = nil
            if let newline = remaining.firstIndex(of: "\n") {
                let firstLine = String(remaining[remaining.startIndex..<newline]).trimmingCharacters(in: .whitespaces)
                if !firstLine.isEmpty && firstLine.count < 20 && !firstLine.contains(" ") {
                    lang = firstLine
                    remaining = String(remaining[remaining.index(after: newline)...])
                }
            }

            // Find closing ```
            if let endRange = remaining.range(of: codePattern) {
                let code = String(remaining[remaining.startIndex..<endRange.lowerBound])
                blocks.append(.code(lang, code.trimmingCharacters(in: .newlines)))
                remaining = String(remaining[endRange.upperBound...])
            } else {
                // Unclosed code block
                blocks.append(.code(lang, remaining))
                remaining = ""
            }
        }

        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.text(remaining))
        }

        return blocks
    }
}

struct CodeBlockView: View {
    let language: String?
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                if let language {
                    Text(language)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                    Haptics.notification(.success)
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
