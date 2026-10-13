// TitledSection.swift
// Purpose: Keep legible, scalable headings within native Form and List sections.
import SwiftUI

/// Uses scalable primary headings while preserving native Form/List grouping.
struct TitledSection<Content: View>: View {
    @ScaledMetric(relativeTo: .headline) private var headingSize = 17
    let title: String
    private let content: () -> Content
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    var body: some View {
        Section {
            content()
        } header: {
            Text(title).font(.system(size: headingSize, weight: .bold))
                .foregroundStyle(Color(uiColor: .label))
                .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
        }
    }
}
#Preview { Form { TitledSection("Your connection") { Text("You and Jordan") } } }
