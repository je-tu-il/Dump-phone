// ios/StackLaunch/ContentView.swift
import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var store = SharedConfigurationStore()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.02, green: 0.04, blue: 0.08), Color(red: 0.04, green: 0.10, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                List {
                    Section { hero }
                        .listRowBackground(Color.clear)
                    Section("Widget stacks") {
                        ForEach(store.configurations) { configuration in
                            NavigationLink(value: configuration.id) { ConfigurationRow(configuration: configuration) }
                        }
                        .onDelete(perform: store.delete)
                    }
                    Section("Global app library") {
                        NavigationLink { LibraryView(store: store) } label: {
                            Label("Manage library", systemImage: "square.grid.3x3.fill")
                        }
                        Text("\(store.library.count) apps available to every stack")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("StackLaunch")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { store.addConfiguration() } label: { Label("New stack", systemImage: "plus") }.tint(.orange) } }
            .navigationDestination(for: WidgetConfigurationList.ID.self) { id in
                if let configuration = store.configurations.first(where: { $0.id == id }) { ConfigurationEditor(configuration: configuration, store: store) }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Widget launcher studio", systemImage: "rectangle.stack.fill").font(.caption.weight(.semibold)).foregroundStyle(.cyan)
            Text("Build compact home-screen stacks from one shared app library.").font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(.white)
            Text("Each stack supports up to 10 apps, custom colors, icon styles, and widget-safe downsampled artwork.").font(.callout).foregroundStyle(.white.opacity(0.72))
        }
        .padding(22)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 30))
    }
}

private struct ConfigurationRow: View {
    let configuration: WidgetConfigurationList
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14).fill(Color(hex: configuration.backgroundColorHex)).frame(width: 46, height: 46).overlay(Image(systemName: "app.badge.fill").foregroundStyle(.cyan))
            VStack(alignment: .leading, spacing: 4) {
                Text(configuration.name).font(.headline)
                Text("\(configuration.applications.count)/\(maxAppsPerStack) apps • shows \(configuration.itemLimit) • \(configuration.iconStyle.title)").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 6)
    }
}

struct ConfigurationEditor: View {
    @State private var draft: WidgetConfigurationList
    @State private var showingAddApp = false
    @State private var backgroundColor: Color
    @FocusState private var focusedField: Field?
    @ObservedObject var store: SharedConfigurationStore
    enum Field: Hashable { case stackName }

    init(configuration: WidgetConfigurationList, store: SharedConfigurationStore) {
        _draft = State(initialValue: configuration)
        _backgroundColor = State(initialValue: Color(hex: configuration.backgroundColorHex))
        self.store = store
    }

    var body: some View {
        List {
            Section("Stack details") {
                TextField("Stack name", text: $draft.name).focused($focusedField, equals: .stackName).submitLabel(.done).onSubmit { focusedField = nil }
                Stepper(value: $draft.itemLimit, in: 1...maxAppsPerStack) { Text("Maximum apps: \(draft.itemLimit)") }
                Toggle("Show icons in widget", isOn: $draft.showIcon)
                ColorPicker("Widget background", selection: $backgroundColor, supportsOpacity: false)
                Picker("Icon style", selection: $draft.iconStyle) { ForEach(IconStyle.allCases) { Text($0.title).tag($0) } }
                Picker("Text alignment", selection: $draft.textAlignment) { ForEach(TextAlignmentOption.allCases) { Text($0.title).tag($0) } }
            }
            Section {
                Button { showingAddApp = true } label: { Label(draft.applicationIds.count >= maxAppsPerStack ? "Stack is full" : "Add from library", systemImage: "plus.circle.fill") }
                    .disabled(draft.applicationIds.count >= maxAppsPerStack)
                ForEach(draft.applications) { app in SelectedApplicationRow(app: app, store: store) }
                    .onMove { indices, newOffset in draft.applications.move(fromOffsets: indices, toOffset: newOffset); draft.applicationIds = draft.applications.map(\.id); persist() }
                    .onDelete { offsets in draft.applications.remove(atOffsets: offsets); draft.applicationIds = draft.applications.map(\.id); persist() }
            } header: { Text("Included apps") } footer: { Text("Stacks are intentionally capped at 10 apps to keep widgets reliable and readable.") }
        }
        .navigationTitle(draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showingAddApp) { AddFromLibraryView(store: store, selectedIds: Set(draft.applicationIds)) { app in guard draft.applicationIds.count < maxAppsPerStack else { return }; draft.applicationIds.append(app.id); draft.applications.append(app); persist() } }
        .onChange(of: draft.name) { _, _ in persist() }
        .onChange(of: draft.itemLimit) { _, _ in persist() }
        .onChange(of: draft.textAlignment) { _, _ in persist() }
        .onChange(of: draft.showIcon) { _, _ in persist() }
        .onChange(of: draft.iconStyle) { _, _ in persist() }
        .onChange(of: backgroundColor) { _, newValue in draft.backgroundColorHex = newValue.hexString(); persist() }
    }
    private func persist() { store.update(draft) }
}

private struct LibraryView: View {
    @ObservedObject var store: SharedConfigurationStore
    @State private var showingAddApp = false
    @State private var showingBulk = false
    var body: some View {
        List {
            Section {
                NavigationLink { AppCatalogView(store: store) } label: {
                    Label("Browse App Catalog", systemImage: "square.grid.2x2.fill")
                }
                Button { showingAddApp = true } label: { Label("Fetch one app", systemImage: "icloud.and.arrow.down.fill") }
                Button { showingBulk = true } label: { Label("Bulk import App Store IDs", systemImage: "square.and.arrow.down.on.square.fill") }
            }
            Section("Apps") { ForEach(store.library) { app in SelectedApplicationRow(app: app, store: store) } }
        }
        .navigationTitle("App Library")
        .sheet(isPresented: $showingAddApp) { AddAppLookupView(store: store) }
        .sheet(isPresented: $showingBulk) { BulkImportView(store: store) }
    }
}

private struct AddFromLibraryView: View {
    @ObservedObject var store: SharedConfigurationStore
    let selectedIds: Set<UUID>
    let onAdd: (LauncherApplication) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @FocusState private var focused: Bool
    private var filtered: [LauncherApplication] { searchText.isEmpty ? store.library : store.library.filter { $0.displayName.localizedStandardContains(searchText) || ($0.appStoreId?.contains(searchText) ?? false) } }
    var body: some View { NavigationStack { List { TextField("Search library", text: $searchText).focused($focused).onSubmit { focused = false }; ForEach(filtered) { app in Button { onAdd(app); dismiss() } label: { HStack { AppIconPreview(app: app).frame(width: 30, height: 30); Text(app.displayName); Spacer(); Image(systemName: selectedIds.contains(app.id) ? "checkmark.circle.fill" : "plus.circle") } }.disabled(selectedIds.contains(app.id)) } }.navigationTitle("Add from Library").toolbar { Button("Done") { dismiss() } } } }
}

private struct AddAppLookupView: View {
    @ObservedObject var store: SharedConfigurationStore
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingTutorial = false
    @FocusState private var focusedField: Field?
    private let lookupService = ITunesAppLookupService()
    enum Field: Hashable { case lookup, search }
    private var filteredApps: [PredefinedApp] { searchText.isEmpty ? PredefinedAppsDatabase.all : PredefinedAppsDatabase.all.filter { $0.name.localizedStandardContains(searchText) || $0.appStoreId.localizedStandardContains(searchText) } }
    var body: some View { NavigationStack { List { Section { TextField("Paste App Store URL or ID", text: $input).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().focused($focusedField, equals: .lookup).submitLabel(.search).onSubmit { Task { await lookupAndAdd() } }; Button { Task { await lookupAndAdd() } } label: { isLoading ? AnyView(ProgressView()) : AnyView(Label("Fetch from iTunes Search API", systemImage: "icloud.and.arrow.down.fill")) }.disabled(isLoading || ITunesAppLookupService.extractAppStoreId(from: input).isEmpty); Button("How to find an App ID?") { showingTutorial = true } } footer: { Text(errorMessage ?? "Artwork is downsampled and saved to the shared App Group for widget access.") }
            Section("Predefined apps") { TextField("Search known apps", text: $searchText).focused($focusedField, equals: .search).onSubmit { focusedField = nil }; ForEach(filteredApps) { predefined in Button { addPredefined(predefined) } label: { Label(predefined.name, systemImage: predefined.iconName ?? "app.fill") }.disabled(store.isInLibrary(predefined)) } } }.navigationTitle("Add App").toolbar { Button("Done") { dismiss() } }.alert("How to find an App ID", isPresented: $showingTutorial) { Button("Got it", role: .cancel) {} } message: { Text("Open an App Store link and look for the number after /id. In apps.apple.com/app/name/id123456789, the App ID is 123456789.") } } }

    private func addPredefined(_ predefined: PredefinedApp) {
        store.addToLibrary(predefined.launcherApplication)
        dismiss()
    }

    private func lookupAndAdd() async {
        focusedField = nil
        isLoading = true
        errorMessage = nil
        do {
            let app = try await lookupService.lookup(input: input)
            store.addToLibrary(app)
            input = ""
            dismiss()
        } catch {
            errorMessage = "Could not fetch that app. Check the ID or URL and try again."
        }
        isLoading = false
    }
}

private struct BulkImportView: View {
    @ObservedObject var store: SharedConfigurationStore
    @Environment(\.dismiss) private var dismiss
    @State private var idsText = ""
    @State private var isImporting = false
    @State private var importedCount = 0
    @FocusState private var editorFocused: Bool
    private let lookupService = ITunesAppLookupService()
    var body: some View {
        NavigationStack {
            List {
                Section("Paste IDs") {
                    TextEditor(text: $idsText)
                        .frame(minHeight: 180)
                        .focused($editorFocused)
                    Text("Use commas or new lines. Example: 389801252, 324684580")
                }
                Section {
                    Button { Task { await importApps() } } label: {
                        if isImporting {
                            ProgressView()
                        } else {
                            Label("Import apps", systemImage: "arrow.down.circle.fill")
                        }
                    }
                    .disabled(isImporting || idsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if importedCount > 0 {
                        Text("Imported \(importedCount) apps")
                    }
                }
            }
            .navigationTitle("Bulk Import")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
    private func importApps() async { editorFocused = false; isImporting = true; let apps = await lookupService.bulkLookup(idsText: idsText); store.addBulkToLibrary(apps); importedCount = apps.count; isImporting = false }
}

// MARK: - App Catalog View

struct AppCatalogView: View {
    @ObservedObject var store: SharedConfigurationStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIds: Set<String> = []
    @State private var searchText: String = ""

    private var filteredApps: [PredefinedApp] {
        if searchText.isEmpty { return PredefinedAppsDatabase.all }
        return PredefinedAppsDatabase.all.filter {
            $0.name.localizedStandardContains(searchText) ||
            $0.urlScheme.localizedStandardContains(searchText) ||
            $0.appStoreId.localizedStandardContains(searchText)
        }
    }

    private var addableCount: Int {
        selectedIds.filter { id in !store.isInLibrary(PredefinedAppsDatabase.allById[id]!) }.count
    }

    var body: some View {
        List {
            ForEach(filteredApps) { app in
                let inLibrary = store.isInLibrary(app)
                let isSelected = selectedIds.contains(app.id)
                Button {
                    if !inLibrary {
                        if isSelected { selectedIds.remove(app.id) } else { selectedIds.insert(app.id) }
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: app.iconName ?? "app.fill")
                            .font(.title3)
                            .foregroundStyle(inLibrary ? .secondary : .cyan)
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(inLibrary ? .secondary : .primary)
                            Text(app.urlScheme)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if inLibrary {
                            Text("In Library")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.green.opacity(0.15), in: Capsule())
                        } else {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? .orange : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .disabled(inLibrary)
            }
        }
        .navigationTitle("App Catalog")
        .searchable(text: $searchText, prompt: "Search apps…")
        .safeAreaInset(edge: .bottom) {
            if !selectedIds.isEmpty {
                Button {
                    let apps = selectedIds.compactMap { PredefinedAppsDatabase.allById[$0]?.launcherApplication }
                    store.addBulkToLibrary(apps)
                    dismiss()
                } label: {
                    Text("Add \(selectedIds.count) to Library")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - Shared Rows

private struct SelectedApplicationRow: View {
    let app: LauncherApplication
    @ObservedObject var store: SharedConfigurationStore
    @State private var textColor: Color
    init(app: LauncherApplication, store: SharedConfigurationStore) { self.app = app; self.store = store; _textColor = State(initialValue: Color(hex: app.textColorHex)) }
    var body: some View { HStack(spacing: 12) { AppIconPreview(app: app).frame(width: 34, height: 34); VStack(alignment: .leading, spacing: 3) { Text(app.displayName).font(.body.weight(.medium)).foregroundStyle(textColor); Text(app.urlScheme).font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); ColorPicker("Text", selection: $textColor, supportsOpacity: false).labelsHidden() }.padding(.vertical, 4).onChange(of: textColor) { _, newValue in var updated = app; updated.textColorHex = newValue.hexString(); store.updateLibraryApp(updated) } }
}

private struct AppIconPreview: View {
    let app: LauncherApplication
    var body: some View { Group { if let image = loadImage() { Image(uiImage: image).resizable().scaledToFill() } else { Image(systemName: app.symbolName).foregroundStyle(.cyan).frame(maxWidth: .infinity, maxHeight: .infinity).background(.cyan.opacity(0.14)) } }.clipShape(.rect(cornerRadius: 8)) }
    private func loadImage() -> UIImage? { guard let fileName = app.iconFileName, let directory = try? SharedIconStorage.iconsDirectoryURL() else { return nil }; return UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path) }
}

#Preview { ContentView() }