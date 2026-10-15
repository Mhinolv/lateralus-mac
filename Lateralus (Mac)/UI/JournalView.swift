import SwiftData
import SwiftUI

/// The private archive: every saved response, searchable and filterable,
/// with a reading pane on the right.
struct JournalView: View {
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel
    @Environment(\.appNow) private var appNow

    @State private var searchText = ""
    @State private var typeFilter: Exercise?
    @State private var dateRange = JournalDateRange()
    @State private var showDatePopover = false
    @State private var selectedID: UUID?
    @State private var entryPendingDeletion: JournalEntry?
    @State private var persistenceErrorMessage = ""
    @State private var showPersistenceError = false
    /// The open edit of the selected entry's response text.
    @State private var responseEdit: ResponseEdit?
    @State private var saveEditErrorMessage = ""
    @State private var showSaveEditError = false
    /// A list selection held back while the user decides about unsaved edits.
    @State private var pendingSelectionID: UUID?
    @State private var showUnsavedEditDialog = false
    @FocusState private var searchFocused: Bool

    private var filtered: [JournalEntry] {
        entries.filter { entry in
            if let typeFilter, entry.exercise != typeFilter { return false }
            if !dateRange.contains(entry.date) { return false }
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

    private var editHasChanges: Bool {
        responseEdit?.hasChanges ?? false
    }

    /// List selection with the unsaved-edit guard: a change of entry asks
    /// first if the open edit has changes.
    private var listSelection: Binding<UUID?> {
        Binding(
            get: { selectedID },
            set: { newID in
                guard newID != selectedID else { return }
                if editHasChanges {
                    pendingSelectionID = newID
                    showUnsavedEditDialog = true
                } else {
                    responseEdit = nil
                    selectedID = newID
                }
            }
        )
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
        .onChange(of: editHasChanges) { _, dirty in
            appModel.sessionHasUnsavedWork = dirty
        }
        .onChange(of: selectedEntry == nil) { _, missing in
            // The entry can vanish under an open edit, e.g. a delete in another window.
            if missing { responseEdit = nil }
        }
        .onDisappear {
            if editHasChanges { appModel.sessionHasUnsavedWork = false }
        }
        .alert("Couldn’t Save", isPresented: $showSaveEditError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveEditErrorMessage)
        }
        .confirmationDialog(
            "Save changes to this response?",
            isPresented: $showUnsavedEditDialog,
            titleVisibility: .visible
        ) {
            if responseEdit?.canSave ?? false {
                Button("Save") {
                    if saveEdit() { applyPendingSelection() }
                }
            }
            Button("Discard Changes", role: .destructive) {
                responseEdit = nil
                applyPendingSelection()
            }
            Button("Cancel", role: .cancel) { pendingSelectionID = nil }
        } message: {
            Text("You edited this response but did not save it.")
        }
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
        VStack(alignment: .leading, spacing: 8) {
            searchRow
            if let summary = dateRange.summary() {
                dateRangeSummary(summary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary)
                TextField("Search your journal", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(Theme.ui(13.5))
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
            .frame(height: 30)
            .background(Theme.surfaceSunken, in: .capsule)

            filterMenu
            dateFilterButton
        }
    }

    /// The active date range, with a button that clears the dates only.
    private func dateRangeSummary(_ summary: String) -> some View {
        HStack(spacing: 6) {
            Text(summary)
                .font(Theme.ui(12))
                .foregroundStyle(Theme.inkTertiary)
            Button {
                dateRange.clear()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear Dates")
            .help("Clear Dates")
        }
    }

    @ViewBuilder
    private var listPane: some View {
        if entries.isEmpty {
            emptyState
                .background(Theme.sidebar)
        } else {
            VStack(spacing: 0) {
                controlsHeader
                entryList
            }
            .background(Theme.sidebar)
        }
    }

    /// Day headers are ordinary unselectable rows rather than `Section`
    /// headers: a sticky header brings the system's near-white header
    /// material with it, and that material is the one surface in the app
    /// that can't be repainted paper.
    private var entryList: some View {
        List(selection: listSelection) {
                ForEach(grouped, id: \.day) { group in
                    SectionLabel(text: JournalDayHeader.title(for: group.day, now: appNow))
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
                            // sidebar tone of this pane.
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: Theme.radiusMedium)
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
                        message: !searchText.isEmpty
                            ? "No entry mentions “\(searchText)”."
                            : dateRange.isActive
                                ? "No entries in this date range."
                                : "No entries in this discipline yet."
                    )
                    .background(Theme.sidebar)
                }
            }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let entry = selectedEntry {
            EntryDetailView(
                entry: entry,
                edit: $responseEdit,
                onSaveEdit: { saveEdit() },
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
            HStack(spacing: 12) {
                Button {
                    appModel.showDiaryComposer = true
                } label: {
                    PrimaryActionButtonLabel(title: "New Diary Entry")
                }
                .buttonStyle(.plain)
                .disabled(appModel.restoreStatus.isBusy)

                Button {
                    appModel.pendingArchiveRestore = true
                } label: {
                    SecondaryActionButtonLabel(title: "Restore Archive…", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.plain)
                .disabled(!appModel.canRestoreArchive)
            }
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
            IconCapsuleLabel(systemImage: "line.3.horizontal.decrease", active: typeFilter != nil)
        }
        .buttonStyle(.plain)
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Filter by exercise")
        .help("Filter by exercise")
    }

    private var dateFilterButton: some View {
        let active = dateRange.isActive
        return Button {
            showDatePopover.toggle()
        } label: {
            IconCapsuleLabel(systemImage: "calendar", active: active)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by date")
        .help("Filter by date")
        .popover(isPresented: $showDatePopover, arrowEdge: .bottom) {
            dateFilterPopover
        }
    }

    /// From / To checkboxes with date pickers. A checkbox turned on starts
    /// at today, and a picker stays disabled while its checkbox is off.
    private var dateFilterPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            dateBoundRow(
                "From",
                date: dateRange.from,
                set: { dateRange.setFrom($0) }
            )
            dateBoundRow(
                "To",
                date: dateRange.to,
                set: { dateRange.setTo($0) }
            )
            Button("Clear Dates") {
                dateRange.clear()
            }
            .buttonStyle(.plain)
            .font(Theme.ui(13, .medium))
            .foregroundStyle(Theme.accent)
            .disabled(!dateRange.isActive)
            .opacity(dateRange.isActive ? 1 : 0.5)
        }
        .padding(16)
        .frame(width: 260, alignment: .leading)
    }

    private func dateBoundRow(_ title: String, date: Date?, set: @escaping (Date?) -> Void) -> some View {
        HStack {
            Toggle(title, isOn: Binding(
                get: { date != nil },
                set: { set($0 ? .now : nil) }
            ))
            .toggleStyle(.checkbox)
            Spacer()
            DatePicker(
                title,
                selection: Binding(get: { date ?? .now }, set: { set($0) }),
                displayedComponents: .date
            )
            .datePickerStyle(.field)
            .labelsHidden()
            .disabled(date == nil)
        }
    }

    // MARK: - Mutations

    /// Consumes the Find-menu's focus request, set before navigating here so
    /// it survives the unsaved-work discard dialog.
    private func consumeSearchFocusRequest() {
        guard appModel.pendingSearchFocus else { return }
        appModel.pendingSearchFocus = false
        if !entries.isEmpty { searchFocused = true }
    }

    /// Writes the open edit through the repository. A failure keeps the
    /// typed text in edit mode.
    @discardableResult
    private func saveEdit() -> Bool {
        guard let edit = responseEdit, edit.canSave, let entry = selectedEntry else { return false }
        do {
            try EntryRepository(context: modelContext).updateResponseText(of: entry, to: edit.trimmed)
            responseEdit = nil
            return true
        } catch {
            saveEditErrorMessage = error.localizedDescription
            showSaveEditError = true
            return false
        }
    }

    private func applyPendingSelection() {
        selectedID = pendingSelectionID
        pendingSelectionID = nil
    }

    private func delete(_ entry: JournalEntry) {
        if selectedID == entry.id {
            selectedID = nil
            responseEdit = nil
        }
        do {
            try EntryRepository(context: modelContext).delete(entry)
        } catch {
            persistenceErrorMessage = error.localizedDescription
            showPersistenceError = true
        }
    }

}

/// The day group title: "Today", "Yesterday", or the weekday and date. A
/// day outside the current year also shows the year.
enum JournalDayHeader {
    static func title(
        for day: Date,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide).month(.wide).day()
        if !calendar.isDate(day, equalTo: now, toGranularity: .year) {
            style = style.year()
        }
        return day.formatted(style)
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
                Spacer(minLength: 0)
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
                .font(Theme.display(15))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            if !entry.responseText.isEmpty {
                Text(entry.responseText)
                    .font(Theme.ui(12.5))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}
