import SwiftData
import SwiftUI

/// The private archive: every saved response, searchable and filterable,
/// with a reading pane on the right.
struct JournalView: View {
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel

    @State private var searchText = ""
    @State private var typeFilter: Exercise?
    @State private var selectedID: UUID?
    @State private var entryPendingDeletion: JournalEntry?
    @State private var persistenceErrorMessage = ""
    @State private var showPersistenceError = false
    @FocusState private var searchFocused: Bool

    private var filtered: [JournalEntry] {
        entries.filter { entry in
            if let typeFilter, entry.exercise != typeFilter { return false }
            guard !searchText.isEmpty else { return true }
            return entry.responseText.localizedCaseInsensitiveContains(searchText)
                || entry.promptHeadline.localizedCaseInsensitiveContains(searchText)
                || (entry.promptDetail?.localizedCaseInsensitiveContains(searchText) ?? false)
                || entry.exercise.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var grouped: [(day: Date, items: [JournalEntry])] {
        let calendar = Calendar.autoupdatingCurrent
        let groups = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { (day: $0, items: groups[$0]!) }
    }

    private var selectedEntry: JournalEntry? {
        guard let selectedID else { return nil }
        return entries.first { $0.id == selectedID }
    }

    var body: some View {
        HSplitView {
            listPane
                .frame(minWidth: 320, idealWidth: 380)
            detailPane
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { consumeSearchFocusRequest() }
        .onChange(of: appModel.pendingSearchFocus) { consumeSearchFocusRequest() }
        .alert("Journal Update Failed", isPresented: $showPersistenceError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceErrorMessage)
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { if !$0 { entryPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Entry", role: .destructive) {
                if let entry = entryPendingDeletion {
                    delete(entry)
                }
                entryPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { entryPendingDeletion = nil }
        } message: {
            Text("The entry and its voice note or sketch will be removed permanently.")
        }
    }

    // MARK: - Panes

    /// Inline search and filter controls in the app's style — this pane's
    /// chrome, not the window's.
    private var controlsHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary)
                TextField("Search entries…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(Theme.ui(14))
                    .foregroundStyle(Theme.ink)
                    .focused($searchFocused)
                    .accessibilityIdentifier("journal-search")
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .inputWell(fill: Theme.surface)

            filterMenu
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var listPane: some View {
        if entries.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                controlsHeader
                entryList
            }
            .background(Theme.background)
        }
    }

    /// Day headers are ordinary unselectable rows rather than `Section`
    /// headers: a sticky header brings the system's near-white header
    /// material with it, and that material is the one surface in the app
    /// that can't be repainted paper.
    private var entryList: some View {
        List(selection: $selectedID) {
                ForEach(grouped, id: \.day) { group in
                    Text(group.day, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(Theme.ui(11, .semibold))
                        .textCase(.uppercase)
                        .kerning(0.9)
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.top, 18)
                        .padding(.bottom, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .selectionDisabled()

                    ForEach(group.items) { entry in
                        JournalRow(entry: entry)
                            .tag(entry.id)
                            .listRowSeparator(.hidden)
                            // Rows default to the system control
                            // background — white, and jarring against the
                            // paper ground every other surface uses.
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                                    .fill(selectedID == entry.id ? Theme.accentSoft : .clear)
                            )
                            .contextMenu {
                                Button("Delete…", role: .destructive) {
                                    entryPendingDeletion = entry
                                }
                            }
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .onDeleteCommand {
                if let entry = selectedEntry { entryPendingDeletion = entry }
            }
            .scrollContentBackground(.hidden)
            .overlay {
                if filtered.isEmpty {
                    EmptyStateView(
                        title: "Nothing matches",
                        message: searchText.isEmpty
                            ? "No entries in this discipline yet."
                            : "No entry mentions “\(searchText)”."
                    )
                    .background(Theme.background)
                }
            }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let entry = selectedEntry {
            EntryDetailView(
                entry: entry,
                onDelete: { entryPendingDeletion = entry }
            )
        } else {
            EmptyStateView(
                title: "No entry selected",
                message: "Choose an entry from the list to read it here."
            )
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No entries yet",
            message: "Finish a challenge or write a diary entry — every idea stays on this Mac."
        ) {
            Button {
                appModel.showDiaryComposer = true
            } label: {
                PrimaryActionButtonLabel(title: "New Diary Entry")
            }
            .buttonStyle(.plain)
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Exercise", selection: $typeFilter) {
                Text("All Exercises").tag(Exercise?.none)
                ForEach(Exercise.journalFilters) { exercise in
                    Label(exercise.title, systemImage: exercise.symbol)
                        .tag(Exercise?.some(exercise))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: typeFilter == nil
                ? "line.3.horizontal.decrease"
                : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(typeFilter == nil ? Theme.inkSecondary : Theme.accent)
                .frame(width: 34, height: 34)
                .background(
                    typeFilter == nil ? Theme.surface : Theme.accentSoft,
                    in: .rect(cornerRadius: Theme.radiusSmall)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .strokeBorder(typeFilter == nil ? Theme.divider : .clear, lineWidth: 1)
                )
                .contentShape(.rect)
                .hoverHighlight()
        }
        .buttonStyle(.plain)
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Filter by exercise")
        .help("Filter by exercise")
    }

    // MARK: - Mutations

    /// Consumes the Find-menu's focus request, set before navigating here so
    /// it survives the unsaved-work discard dialog.
    private func consumeSearchFocusRequest() {
        guard appModel.pendingSearchFocus else { return }
        appModel.pendingSearchFocus = false
        if !entries.isEmpty { searchFocused = true }
    }

    private func delete(_ entry: JournalEntry) {
        if selectedID == entry.id { selectedID = nil }
        do {
            try EntryRepository(context: modelContext).delete(entry)
        } catch {
            persistenceErrorMessage = error.localizedDescription
            showPersistenceError = true
        }
    }

}

/// A journal row reads top-down — what discipline, what was asked, what
/// came back — rather than left-to-right across a tag column. At 380 pt
/// wide there isn't room for both a tag gutter and a legible headline.
struct JournalRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Tag(text: entry.exercise.title)
                if entry.isDaily { Badge(text: "Daily") }
                if entry.voiceNoteFile != nil {
                    Image(systemName: "waveform")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                        .accessibilityLabel("Has voice note")
                        .help("Includes a voice note")
                }
                if entry.sketchData != nil {
                    Image(systemName: "scribble.variable")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                        .accessibilityLabel("Has sketch")
                        .help("Includes a sketch")
                }
            }
            Text(entry.promptHeadline)
                .font(Theme.ui(14, .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            if !entry.responseText.isEmpty {
                Text(entry.responseText)
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.inkTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7)
    }
}
