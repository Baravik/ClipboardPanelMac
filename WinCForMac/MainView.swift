import SwiftUI

// MARK: - Main Clipboard History View

/// The primary view shown in the floating panel — a searchable list of clipboard items.
struct MainView: View {

    @ObservedObject var clipboardMonitor: ClipboardMonitor
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @State private var hoveredItemID: UUID?

    /// Called when the user selects an item to paste.
    var onItemSelected: ((ClipboardItem) -> Void)?
    /// Called when the user wants to dismiss the panel.
    var onDismiss: (() -> Void)?

    private var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardMonitor.items
        }
        return clipboardMonitor.items.filter {
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            Divider()

            if filteredItems.isEmpty {
                emptyState
            } else {
                itemList
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 380, height: 420)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            selectedIndex = 0
        }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13))

            TextField("Search clipboard…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit {
                    selectCurrent()
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clipboard")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "Clipboard history is empty" : "No matching items")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "Copy something to get started" : "Try a different search term")
                .font(.system(size: 11))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var itemList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                    ClipboardItemRow(
                        item: item,
                        isSelected: index == selectedIndex,
                        isHovered: hoveredItemID == item.id,
                        index: index
                    )
                    .id(item.id)
                    .onTapGesture {
                        onItemSelected?(item)
                    }
                    .onHover { hovering in
                        hoveredItemID = hovering ? item.id : nil
                        if hovering {
                            selectedIndex = index
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onKeyPress(.upArrow) {
                moveSelection(by: -1)
                scrollTo(proxy: proxy)
                return .handled
            }
            .onKeyPress(.downArrow) {
                moveSelection(by: 1)
                scrollTo(proxy: proxy)
                return .handled
            }
            .onKeyPress(.return) {
                selectCurrent()
                return .handled
            }
            .onKeyPress(.escape) {
                onDismiss?()
                return .handled
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(filteredItems.count) item\(filteredItems.count == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))

            Spacer()

            if !clipboardMonitor.items.isEmpty {
                Button(action: {
                    clipboardMonitor.clearHistory()
                }) {
                    Text("Clear All")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Keyboard Navigation

    private func moveSelection(by offset: Int) {
        let newIndex = selectedIndex + offset
        if newIndex >= 0 && newIndex < filteredItems.count {
            selectedIndex = newIndex
        }
    }

    private func scrollTo(proxy: ScrollViewProxy) {
        guard selectedIndex >= 0 && selectedIndex < filteredItems.count else { return }
        withAnimation(.easeInOut(duration: 0.1)) {
            proxy.scrollTo(filteredItems[selectedIndex].id, anchor: .center)
        }
    }

    private func selectCurrent() {
        guard !filteredItems.isEmpty,
              selectedIndex >= 0,
              selectedIndex < filteredItems.count else { return }
        onItemSelected?(filteredItems[selectedIndex])
    }
}

// MARK: - Clipboard Item Row

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isHovered: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 10) {
            // Index badge
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)

                Text(item.relativeTime)
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }

            Spacer()

            // Show character count
            Text("\(item.content.count) chars")
                .font(.system(size: 9))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Visual Effect View (NSVisualEffectView wrapper)

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
