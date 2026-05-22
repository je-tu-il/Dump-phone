import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var store = SharedConfigurationStore()
    @State private var selection: WidgetConfigurationList.ID?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.02, green: 0.04, blue: 0.08), Color(red: 0.04, green: 0.10, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                VStack(spacing: 18) {
                    hero
                    List(selection: $selection) {
                        Section("Widget configurations") {
                            ForEach(store.configurations) { configuration in
                                NavigationLink(value: configuration.id) {
                                    ConfigurationRow(configuration: configuration)
                                }
                            }
                            .onDelete(perform: store.delete)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .clipShape(.rect(cornerRadius: 28))
                }
                .padding()
            }
            .navigationTitle("StackLaunch")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { store.addConfiguration(); WidgetCenter.shared.reloadAllTimelines() } label: {
                        Label("New stack", systemImage: "plus")
                    }
                    .tint(.orange)
                }
            }
            .navigationDestination(for: WidgetConfigurationList.ID.self) { id in
                if let configuration = store.configurations.first(where: { $0.id == id }) {
                    ConfigurationEditor(configuration: configuration, store: store)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Widget launcher studio", systemImage: "rectangle.stack.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.cyan)
            Text("Build the launch lists your home screen widgets will display.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("Create multiple stacks here, then long-press a widget and choose the exact stack in Edit Widget. Smart Stacks stay native to iOS.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 30))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "arrow.up.forward.app.fill")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(.orange.gradient)
                .padding(24)
        }
    }
}

private struct ConfigurationRow: View {
    let configuration: WidgetConfigurationList

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(.cyan.opacity(0.18))
                Image(systemName: "square.grid.2x2.fill").foregroundStyle(.cyan)
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(configuration.name).font(.headline)
                Text("\(configuration.visibleApplications.count) links • \(configuration.textAlignment.title) aligned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ConfigurationEditor: View {
    @State private var draft: WidgetConfigurationList
    @ObservedObject var store: SharedConfigurationStore

    init(configuration: WidgetConfigurationList, store: SharedConfigurationStore) {
        _draft = State(initialValue: configuration)
        self.store = store
    }

    var body: some View {
        List {
            Section("Identity") {
                TextField("Widget name", text: $draft.name)
                Stepper("Show \(draft.itemLimit) apps", value: $draft.itemLimit, in: 1...8)
                Picker("Text alignment", selection: $draft.textAlignment) {
                    ForEach(TextAlignmentOption.allCases) { option in Text(option.title).tag(option) }
                }
            }
            Section("Selected apps") {
                ForEach(draft.applications) { app in
                    Label(app.displayName, systemImage: app.symbolName)
                }
                .onMove { indices, newOffset in
                    draft.applications.move(fromOffsets: indices, toOffset: newOffset)
                    persist()
                }
                .onDelete { offsets in
                    draft.applications.remove(atOffsets: offsets)
                    persist()
                }
            }
            Section("Known URL schemes") {
                ForEach(KnownApplications.all) { app in
                    Button {
                        if !draft.applications.contains(where: { $0.displayName == app.displayName }) {
                            draft.applications.append(app)
                            persist()
                        }
                    } label: {
                        HStack {
                            Label(app.displayName, systemImage: app.symbolName)
                            Spacer()
                            Text(app.urlScheme).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Shortcut workaround") {
                Text("For apps without public URL schemes, create an Apple Shortcut and add a URL like shortcuts://run-shortcut?name=YourShortcutName.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(draft.name)
        .toolbar { EditButton() }
        .onChange(of: draft.name) { _, _ in persist() }
        .onChange(of: draft.itemLimit) { _, _ in persist() }
        .onChange(of: draft.textAlignment) { _, _ in persist() }
    }

    private func persist() {
        store.update(draft)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview { ContentView() }
