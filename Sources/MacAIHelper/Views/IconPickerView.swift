// IconPickerView.swift
// A visual SF Symbol icon picker with a searchable multi-column grid popover.

import SwiftUI

/// Curated collection of SF Symbols organized by category for prompt icon selection.
enum SFSymbolCatalog {
    struct Category: Identifiable {
        let id: String
        let name: String
        let symbols: [String]
    }

    /// cSpell:disable
    static let categories: [Category] = [
        Category(id: "communication", name: "Communication", symbols: [
            "text.bubble", "text.bubble.fill", "bubble.left", "bubble.left.fill",
            "envelope", "envelope.fill", "envelope.open", "paperplane", "paperplane.fill",
            "message", "message.fill", "phone", "phone.fill", "video", "video.fill",
        ]),
        Category(id: "technology", name: "Technology", symbols: [
            "desktopcomputer", "laptopcomputer", "server.rack", "cpu",
            "terminal", "terminal.fill", "network", "wifi", "antenna.radiowaves.left.and.right",
            "externaldrive", "internaldrive", "memorychip", "printer", "scanner",
        ]),
        Category(id: "web", name: "Web & Globe", symbols: [
            "globe", "globe.americas", "globe.europe.africa", "globe.asia.australia",
            "link", "link.circle", "safari", "at", "number",
        ]),
        Category(id: "writing", name: "Writing & Documents", symbols: [
            "pencil", "pencil.circle", "pencil.line", "square.and.pencil",
            "doc", "doc.text", "doc.text.fill", "doc.on.doc", "doc.on.clipboard",
            "note.text", "list.bullet", "list.number", "text.alignleft", "text.justify",
        ]),
        Category(id: "books", name: "Books & Education", symbols: [
            "book", "book.fill", "book.closed", "book.closed.fill",
            "books.vertical", "books.vertical.fill", "bookmark", "bookmark.fill",
            "graduationcap", "graduationcap.fill", "backpack", "backpack.fill",
        ]),
        Category(id: "creative", name: "Creative", symbols: [
            "paintbrush", "paintbrush.fill", "paintbrush.pointed", "paintpalette",
            "photo", "photo.fill", "camera", "camera.fill",
            "wand.and.stars", "sparkles", "theatermasks", "music.note",
        ]),
        Category(id: "tools", name: "Tools & Settings", symbols: [
            "gearshape", "gearshape.fill", "gearshape.2", "wrench", "wrench.fill",
            "hammer", "hammer.fill", "screwdriver", "screwdriver.fill",
            "magnifyingglass", "magnifyingglass.circle", "slider.horizontal.3",
        ]),
        Category(id: "ideas", name: "Ideas & Science", symbols: [
            "lightbulb", "lightbulb.fill", "brain.head.profile", "brain",
            "atom", "function", "sum", "percent", "chart.bar", "chart.bar.fill",
            "chart.line.uptrend.xyaxis", "chart.pie", "waveform",
        ]),
        Category(id: "arrows", name: "Arrows & Actions", symbols: [
            "arrow.right", "arrow.left", "arrow.up", "arrow.down",
            "arrow.triangle.2.circlepath", "arrow.clockwise", "arrow.counterclockwise",
            "arrowshape.turn.up.right", "arrowshape.turn.up.left",
            "arrow.up.doc", "arrow.down.doc", "square.and.arrow.up",
        ]),
        Category(id: "people", name: "People", symbols: [
            "person", "person.fill", "person.2", "person.2.fill",
            "person.crop.circle", "person.badge.plus", "person.badge.key",
            "figure.wave", "hand.raised", "hand.thumbsup", "hand.thumbsdown",
        ]),
        Category(id: "symbols", name: "Symbols", symbols: [
            "star", "star.fill", "heart", "heart.fill",
            "flag", "flag.fill", "bell", "bell.fill",
            "bolt", "bolt.fill", "flame", "flame.fill",
            "checkmark.circle", "checkmark.circle.fill", "xmark.circle", "xmark.circle.fill",
            "exclamationmark.triangle", "exclamationmark.triangle.fill",
            "info.circle", "info.circle.fill", "questionmark.circle",
        ]),
        Category(id: "security", name: "Security & Privacy", symbols: [
            "lock", "lock.fill", "lock.open", "lock.shield",
            "key", "key.fill", "shield", "shield.fill",
            "eye", "eye.fill", "eye.slash", "eye.slash.fill",
        ]),
        Category(id: "code", name: "Code & Development", symbols: [
            "chevron.left.forwardslash.chevron.right", "curlybraces",
            "terminal", "apple.terminal", "play", "play.fill",
            "stop", "stop.fill", "pause", "pause.fill",
            "bug", "ant", "ladybug",
        ]),
    ]
    /// cSpell:enable

    /// All symbols flattened into a single array (deduplicated).
    static var allSymbols: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for category in categories {
            for symbol in category.symbols {
                if seen.insert(symbol).inserted {
                    result.append(symbol)
                }
            }
        }
        return result
    }
}

// MARK: - IconPickerView

/// A button that opens a popover with a searchable multi-column grid of SF Symbol icons.
struct IconPickerView: View {
    @Binding var selectedIcon: String

    @State private var showingPicker = false
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil

    private let gridColumns = Array(repeating: GridItem(.fixed(36), spacing: 6), count: 6)

    var body: some View {
        HStack(spacing: 8) {
            Text("Icon")
                .font(.body)

            Button {
                showingPicker.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selectedIcon)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24, height: 24)

                    Text(selectedIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
                iconPickerPopover
            }
        }
    }

    // MARK: - Popover Content

    private var iconPickerPopover: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search icons…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    categoryChip(name: "All", id: nil)
                    ForEach(SFSymbolCatalog.categories) { category in
                        categoryChip(name: category.name, id: category.id)
                    }
                }
            }

            Divider()

            // Icon grid
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 6) {
                    ForEach(filteredSymbols, id: \.self) { symbol in
                        iconButton(symbol)
                    }
                }
                .padding(4)
            }
        }
        .padding(10)
        .frame(width: 280, height: 340)
    }

    private func categoryChip(name: String, id: String?) -> some View {
        Button {
            selectedCategory = id
        } label: {
            Text(name)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    selectedCategory == id
                        ? Color.accentColor.opacity(0.2)
                        : Color.secondary.opacity(0.1),
                    in: Capsule()
                )
                .foregroundStyle(selectedCategory == id ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    private func iconButton(_ symbol: String) -> some View {
        Button {
            selectedIcon = symbol
            showingPicker = false
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background(
                    symbol == selectedIcon
                        ? Color.accentColor.opacity(0.2)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 4)
                )
                .foregroundStyle(symbol == selectedIcon ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .help(symbol)
    }

    // MARK: - Filtering

    private var filteredSymbols: [String] {
        let baseSymbols: [String]
        if let categoryId = selectedCategory,
           let category = SFSymbolCatalog.categories.first(where: { $0.id == categoryId }) {
            baseSymbols = category.symbols
        } else {
            baseSymbols = SFSymbolCatalog.allSymbols
        }

        if searchText.isEmpty {
            return baseSymbols
        }
        let query = searchText.lowercased()
        return baseSymbols.filter { $0.lowercased().contains(query) }
    }
}
