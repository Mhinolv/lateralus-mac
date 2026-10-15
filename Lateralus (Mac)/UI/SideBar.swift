import SwiftUI

/// The app's own inline sidebar — themed chrome, not a system split view.
/// Wordmark, main navigation, and the full practice catalog. New Diary Entry
/// lives in the window toolbar.
struct SideBar: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Lateralus")
                .font(Theme.display(22, italic: true))
                .kerning(0.2)
                .foregroundStyle(Theme.ink)
                .padding(.top, 16)
                .padding(.leading, 12)
                .padding(.bottom, 26)

            VStack(alignment: .leading, spacing: 2) {
                mainItem("Today", symbol: "circle", item: .today, id: "nav-today")
                mainItem("Journal", symbol: "text.alignleft", item: .journal, id: "nav-journal")
                mainItem("Insights", symbol: "chart.bar.fill", item: .insights, id: "nav-insights")
            }

            SectionLabel(text: "Practice", tint: Theme.inkTertiary)
                .padding(.top, 24)
                .padding(.leading, 12)
                .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Exercise.practice) { exercise in
                        practiceItem(exercise)
                    }
                }
            }

        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .frame(width: 264)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.divider).frame(width: 1)
        }
    }

    private func mainItem(_ title: String, symbol: String, item: SidebarItem, id: String) -> some View {
        let selected = appModel.selection == item
        return Button {
            appModel.select(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selected ? Theme.accentStrong : Theme.inkSecondary)
                    .frame(width: 16)
                Text(title)
                    .font(Theme.ui(14, .medium))
                    .foregroundStyle(selected ? Theme.accentStrong : Theme.inkSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                selected ? Theme.accentSoft : .clear,
                in: .rect(cornerRadius: Theme.radiusSmall)
            )
            .contentShape(.rect)
            .hoverHighlight()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func practiceItem(_ exercise: Exercise) -> some View {
        let selected = appModel.selection == .practice(exercise)
        return Button {
            appModel.select(.practice(exercise))
        } label: {
            HStack(spacing: 12) {
                DisciplineDot(color: selected ? Theme.accent : Theme.inkTertiary)
                    .frame(width: 16, height: 16)
                Text(exercise.title)
                    .font(Theme.ui(13.5, .regular))
                    .foregroundStyle(selected ? Theme.accentStrong : Theme.inkSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                selected ? Theme.accentSoft : .clear,
                in: .rect(cornerRadius: Theme.radiusSmall)
            )
            .contentShape(.rect)
            .hoverHighlight()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practice-item-\(exercise.rawValue)")
    }
}
