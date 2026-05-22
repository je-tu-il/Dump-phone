import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var store = SharedConfigurationStore()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.02, green: 0.04, blue: 0.08), Color(red: 0.04, green: 0.10, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                VStack(spacing: 18) {
                    hero
                    List {
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
                    Button { store.addConfiguration() } label: {
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
            Text("Build deep-link stacks with real App Store icons.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("Create large app lists, choose a stack from Edit Widget, and let the widget read everything from shared App Group storage.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 30))
    }
}

private struct ConfigurationRow: View {
    let configuration: WidgetConfigurationList

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(.cyan.opacity(0.18))
                Image(systemName: configuration.showIcon ? "app.badge.fill" : "text.alignleft").foregroundStyle(.cyan)
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(configuration.name).font(.headline)
                Text("\(configuration.applications.count) apps • shows \(configuration.itemLimit) • icons \(configuration.showIcon ? "on" : "off")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ConfigurationEditor: View {
    @State private var draft: WidgetConfigurationList
    @State private var showingAddApp = false
    @FocusState private var focusedField: Field?
    @ObservedObject var store: SharedConfigurationStore

    enum Field: Hashable { case stackName }

    init(configuration: WidgetConfigurationList, store: SharedConfigurationStore) {
        _draft = State(initialValue: configuration)
        self.store = store
    }

    var body: some View {
        List {
            Section("Stack details") {
                TextField("Stack name", text: $draft.name)
                    .focused($focusedField, equals: .stackName)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                Stepper(value: $draft.itemLimit, in: 1...250) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Maximum apps")
                        Text("Widget shows up to \(draft.itemLimit) of \(draft.applications.count) selected apps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Show icons in widget", isOn: $draft.showIcon)
                Picker("Text alignment", selection: $draft.textAlignment) {
                    ForEach(TextAlignmentOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            }

            Section {
                Button { showingAddApp = true } label: {
                    Label("Add app", systemImage: "plus.circle.fill")
                }
                if draft.applications.isEmpty {
                    ContentUnavailableView("No apps in this stack", systemImage: "square.grid.2x2", description: Text("Add known apps or paste an App Store URL/ID."))
                } else {
                    ForEach(draft.applications) { app in
                        SelectedApplicationRow(app: app)
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
            } header: {
                Text("Included apps")
            } footer: {
                Text("Use Edit to reorder large stacks. Every change is saved to shared App Group storage for the widget.")
            }
        }
        .navigationTitle(draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showingAddApp) {
            AddAppView(existingApps: draft.applications) { app in
                guard !draft.applications.contains(where: { $0.appStoreId == app.appStoreId && $0.displayName == app.displayName }) else { return }
                draft.applications.append(app)
                persist()
            }
        }
        .onChange(of: draft.name) { _, _ in persist() }
        .onChange(of: draft.itemLimit) { _, _ in persist() }
        .onChange(of: draft.textAlignment) { _, _ in persist() }
        .onChange(of: draft.showIcon) { _, _ in persist() }
    }

    private func persist() {
        store.update(draft)
    }
}

private struct AddAppView: View {
    let existingApps: [LauncherApplication]
    let onAdd: (LauncherApplication) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingTutorial = false
    @FocusState private var focusedField: Field?
    private let lookupService = ITunesAppLookupService()

    enum Field: Hashable { case lookup, search }

    private var filteredApps: [PredefinedApp] {
        guard !searchText.isEmpty else { return PredefinedAppsDatabase.all }
        return PredefinedAppsDatabase.all.filter { $0.name.localizedStandardContains(searchText) || $0.urlScheme.localizedStandardContains(searchText) || $0.appStoreId.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Paste App Store URL or ID", text: $input)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .lookup)
                        .submitLabel(.search)
                        .onSubmit { Task { await lookupAndAdd() } }
                    Button { Task { await lookupAndAdd() } } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Label("Fetch from iTunes Search API", systemImage: "icloud.and.arrow.down.fill")
                        }
                    }
                    .disabled(isLoading || ITunesAppLookupService.extractAppStoreId(from: input).isEmpty)
                    Button("How to find an App ID?") { showingTutorial = true }
                        .font(.footnote.weight(.semibold))
                } header: {
                    Text("Add from App Store")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else {
                        Text("Icons are downloaded into the shared App Group container so widgets can render them.")
                    }
                }

                Section("Search predefined apps") {
                    TextField("Search name, scheme, or ID", text: $searchText)
                        .focused($focusedField, equals: .search)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                    ForEach(filteredApps) { predefined in
                        Button {
                            onAdd(predefined.launcherApplication)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: predefined.iconName ?? "app.fill")
                                    .foregroundStyle(.cyan)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(predefined.name)
                                    Text("\(predefined.urlScheme) • ID \(predefined.appStoreId)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: alreadyAdded(predefined) ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundStyle(alreadyAdded(predefined) ? .green : .orange)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(alreadyAdded(predefined))
                    }
                }
            }
            .navigationTitle("Add App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .alert("How to find an App ID", isPresented: $showingTutorial) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("Open an App Store link and look for the number after /id. In apps.apple.com/app/name/id123456789, the App ID is 123456789. Paste either the full link or just that number here.")
            }
            .presentationDetents([.large])
            .presentationContentInteraction(.scrolls)
        }
    }

    private func alreadyAdded(_ predefined: PredefinedApp) -> Bool {
        existingApps.contains { $0.appStoreId == predefined.appStoreId && $0.displayName == predefined.name }
    }

    private func lookupAndAdd() async {
        focusedField = nil
        isLoading = true
        errorMessage = nil
        do {
            let app = try await lookupService.lookup(input: input)
            onAdd(app)
            input = ""
        } catch {
            errorMessage = "Could not fetch that app. Check the App Store ID or URL and try again."
        }
        isLoading = false
    }
}

private struct SelectedApplicationRow: View {
    let app: LauncherApplication

    var body: some View {
        HStack(spacing: 12) {
            AppIconPreview(app: app)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.displayName)
                    .font(.body.weight(.medium))
                Text(app.urlScheme)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AppIconPreview: View {
    let app: LauncherApplication

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: app.symbolName)
                    .foregroundStyle(.cyan)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.cyan.opacity(0.14))
            }
        }
        .clipShape(.rect(cornerRadius: 8))
    }

    private func loadImage() -> UIImage? {
        guard let fileName = app.iconFileName,
              let directory = try? SharedIconStorage.iconsDirectoryURL() else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path)
    }
}

#Preview { ContentView() }
