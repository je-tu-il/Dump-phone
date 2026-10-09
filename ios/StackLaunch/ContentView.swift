import SwiftUI
import WidgetKit

// MARK: - Écran Principal
struct ContentView: View {
    @StateObject private var store = SharedConfigurationStore()
    @State private var showingReloadAlert = false
    @State private var showingCatalogSheet = false
    @State private var showingCustomAppSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.04, blue: 0.08),
                        Color(red: 0.04, green: 0.10, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                List {
                    Section {
                        heroView
                    }
                    .listRowBackground(Color.clear)

                    // Section des Piles de Widgets
                    Section {
                        if store.configurations.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Aucune pile configurée")
                                    .font(.headline)
                                Text("Créez votre première pile de lancement pour l'afficher sur vos widgets.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button {
                                    store.addConfiguration()
                                } label: {
                                    Label("Créer une pile", systemImage: "plus.circle.fill")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 8)
                        } else {
                            ForEach(store.configurations) { configuration in
                                NavigationLink(value: configuration.id) {
                                    ConfigurationRow(configuration: configuration)
                                }
                            }
                            .onDelete(perform: store.delete)
                        }
                    } header: {
                        HStack {
                            Text("Piles de widgets")
                            Spacer()
                            Button {
                                store.addConfiguration()
                            } label: {
                                Label("Nouvelle", systemImage: "plus")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(.cyan)
                        }
                    } footer: {
                        Text("Chaque pile peut être assignée à un ou plusieurs widgets sur votre écran d'accueil.")
                    }

                    // Section Bibliothèque d'applications
                    Section("Bibliothèque d'applications") {
                        NavigationLink {
                            LibraryView(store: store)
                        } label: {
                            HStack {
                                Label("Gérer la bibliothèque", systemImage: "square.grid.3x3.fill")
                                Spacer()
                                Text("\(store.library.count) apps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            showingCatalogSheet = true
                        } label: {
                            Label("Catalogue d'applications prêtes", systemImage: "sparkles.rectangle.stack.fill")
                        }

                        Button {
                            showingCustomAppSheet = true
                        } label: {
                            Label("Ajouter une app personnalisée (URL scheme)", systemImage: "link.badge.plus")
                        }
                    }

                    // Section Système & Synchronisation
                    Section("Système & Synchronisation") {
                        Button {
                            store.forceReload()
                            showingReloadAlert = true
                        } label: {
                            Label("Actualiser les widgets maintenant", systemImage: "arrow.clockwise.circle.fill")
                        }

                        NavigationLink {
                            DiagnosticView(store: store)
                        } label: {
                            Label("Diagnostics & Logs App Group", systemImage: "terminal.fill")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("StackLaunch")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.addConfiguration()
                    } label: {
                        Label("Nouvelle pile", systemImage: "plus")
                    }
                    .tint(.cyan)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let configuration = store.configurations.first(where: { $0.id == id }) {
                    ConfigurationEditor(configuration: configuration, store: store)
                }
            }
            .sheet(isPresented: $showingCatalogSheet) {
                CatalogBrowserView(store: store)
            }
            .sheet(isPresented: $showingCustomAppSheet) {
                AddCustomAppView { customApp in
                    store.addToLibrary(customApp)
                }
            }
            .alert("Widgets actualisés", isPresented: $showingReloadAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Toutes les données ont été synchronisées avec l'App Group et WidgetKit.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var heroView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Lanceur de widgets iOS", systemImage: "rectangle.stack.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.cyan)
            Text("Lancez vos apps en un geste depuis votre écran.")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("Personnalisez vos piles, vos couleurs et vos icônes. Parfaitement synchronisé avec vos widgets.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Ligne d'une Configuration dans la Liste
private struct ConfigurationRow: View {
    let configuration: WidgetConfigurationList

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: configuration.backgroundColorHex))
                    .frame(width: 44, height: 44)
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(.cyan)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(configuration.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Text("\(configuration.applications.count) apps")
                    Text("•")
                    Text("affiche \(configuration.itemLimit)")
                    Text("•")
                    Text(configuration.iconStyle.title)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Mini preview des 4 premières icônes
                if !configuration.applications.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(configuration.applications.prefix(5))) { app in
                            Image(systemName: app.symbolName.isEmpty ? "app.fill" : app.symbolName)
                                .font(.system(size: 9))
                                .foregroundStyle(.cyan.opacity(0.8))
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Éditeur de Configuration avec Aperçu en Direct
struct ConfigurationEditor: View {
    @State private var draft: WidgetConfigurationList
    @State private var showingAddFromLibrary = false
    @State private var showingAddFromCatalog = false
    @State private var backgroundColor: Color
    @FocusState private var isNameFocused: Bool
    @ObservedObject var store: SharedConfigurationStore

    init(configuration: WidgetConfigurationList, store: SharedConfigurationStore) {
        _draft = State(initialValue: configuration)
        _backgroundColor = State(initialValue: Color(hex: configuration.backgroundColorHex))
        self.store = store
    }

    var body: some View {
        List {
            // Section Aperçu en direct du Widget
            Section {
                LiveWidgetPreviewCard(configuration: draft)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Aperçu en direct du widget")
            }

            // Paramètres généraux
            Section("Paramètres du widget") {
                TextField("Nom de la pile", text: $draft.name)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit { isNameFocused = false }

                Stepper(value: $draft.itemLimit, in: 1...maxAppsPerStack) {
                    HStack {
                        Text("Nombre d'apps affichées :")
                        Spacer()
                        Text("\(draft.itemLimit)")
                            .font(.headline)
                            .foregroundStyle(.cyan)
                    }
                }

                ColorPicker("Couleur d'arrière-plan", selection: $backgroundColor, supportsOpacity: false)

                Picker("Style des icônes", selection: $draft.iconStyle) {
                    ForEach(IconStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }

                Picker("Alignement du texte", selection: $draft.textAlignment) {
                    ForEach(TextAlignmentOption.allCases) { align in
                        Text(align.title).tag(align)
                    }
                }

                Toggle("Afficher les icônes", isOn: $draft.showIcon)
            }

            // Applications incluses
            Section {
                Button {
                    showingAddFromLibrary = true
                } label: {
                    Label(
                        draft.applicationIds.count >= maxAppsPerStack ? "Pile complète (10 max)" : "Ajouter depuis la bibliothèque",
                        systemImage: "square.grid.3x3.fill"
                    )
                }
                .disabled(draft.applicationIds.count >= maxAppsPerStack)

                Button {
                    showingAddFromCatalog = true
                } label: {
                    Label("Ajouter directement depuis le catalogue", systemImage: "sparkles")
                        .foregroundStyle(.cyan)
                }
                .disabled(draft.applicationIds.count >= maxAppsPerStack)

                if draft.applications.isEmpty {
                    Text("Aucune application dans cette pile. Ajoutez-en depuis la bibliothèque ou le catalogue.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(draft.applications) { app in
                        SelectedApplicationRow(app: app, store: store)
                    }
                    .onMove { indices, newOffset in
                        draft.applications.move(fromOffsets: indices, toOffset: newOffset)
                        draft.applicationIds = draft.applications.map(\.id)
                        persist()
                    }
                    .onDelete { offsets in
                        draft.applications.remove(atOffsets: offsets)
                        draft.applicationIds = draft.applications.map(\.id)
                        persist()
                    }
                }
            } header: {
                Text("Applications incluses (\(draft.applications.count)/\(maxAppsPerStack))")
            } footer: {
                Text("Faites glisser pour réordonner les applications. Les premières apparaîtront en priorité sur le widget.")
            }
        }
        .navigationTitle(draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $showingAddFromLibrary) {
            AddFromLibraryView(store: store, selectedIds: Set(draft.applicationIds)) { app in
                guard draft.applicationIds.count < maxAppsPerStack else { return }
                draft.applicationIds.append(app.id)
                draft.applications.append(app)
                persist()
            }
        }
        .sheet(isPresented: $showingAddFromCatalog) {
            CatalogBrowserView(store: store) { app in
                guard draft.applicationIds.count < maxAppsPerStack else { return }
                store.addToLibrary(app)
                if !draft.applicationIds.contains(app.id) {
                    draft.applicationIds.append(app.id)
                    draft.applications.append(app)
                    persist()
                }
            }
        }
        .onChange(of: draft.name) { _, _ in persist() }
        .onChange(of: draft.itemLimit) { _, _ in persist() }
        .onChange(of: draft.textAlignment) { _, _ in persist() }
        .onChange(of: draft.showIcon) { _, _ in persist() }
        .onChange(of: draft.iconStyle) { _, _ in persist() }
        .onChange(of: backgroundColor) { _, newValue in
            draft.backgroundColorHex = newValue.hexString()
            persist()
        }
    }

    private func persist() {
        store.update(draft)
    }
}

// MARK: - Carte d'Aperçu en Direct du Widget
private struct LiveWidgetPreviewCard: View {
    let configuration: WidgetConfigurationList
    @State private var previewSize: Int = 1 // 0 = Petit, 1 = Moyen

    var body: some View {
        VStack(spacing: 12) {
            Picker("Taille d'aperçu", selection: $previewSize) {
                Text("Petit (Small)").tag(0)
                Text("Moyen (Medium)").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if previewSize == 0 {
                // Aperçu Small
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(hex: configuration.backgroundColorHex))
                        .frame(width: 155, height: 155)
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(configuration.name.isEmpty ? "Pile" : configuration.name)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.cyan)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.cyan.opacity(0.8))
                        }

                        let visible = Array(configuration.visibleApplications.prefix(4))
                        if visible.isEmpty {
                            Spacer()
                            Text("Vide")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity)
                            Spacer()
                        } else if visible.count <= 2 {
                            VStack(spacing: 5) {
                                ForEach(visible) { app in
                                    HStack(spacing: 6) {
                                        if configuration.showIcon {
                                            Image(systemName: app.symbolName.isEmpty ? "app.fill" : app.symbolName)
                                                .font(.system(size: 11))
                                                .foregroundStyle(.cyan)
                                        }
                                        Text(app.displayName)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Color(hex: app.textColorHex))
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 5)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.12)))
                                }
                            }
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                                ForEach(visible) { app in
                                    VStack(spacing: 2) {
                                        if configuration.showIcon {
                                            Image(systemName: app.symbolName.isEmpty ? "app.fill" : app.symbolName)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.cyan)
                                        }
                                        Text(app.displayName)
                                            .font(.system(size: 8, weight: .semibold))
                                            .foregroundStyle(Color(hex: app.textColorHex))
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.12)))
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(width: 155, height: 155)
                }
                .padding(.vertical, 4)
            } else {
                // Aperçu Medium
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(hex: configuration.backgroundColorHex))
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(configuration.name.isEmpty ? "Pile" : configuration.name)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.cyan)
                                .lineLimit(1)
                            Spacer()
                            Text("\(configuration.visibleApplications.count) apps")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        let apps = configuration.visibleApplications
                        if apps.isEmpty {
                            Spacer()
                            Text("Aucune application sélectionnée")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity)
                            Spacer()
                        } else {
                            let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(apps) { app in
                                    HStack(spacing: 6) {
                                        if configuration.showIcon {
                                            Image(systemName: app.symbolName.isEmpty ? "app.fill" : app.symbolName)
                                                .font(.system(size: 11))
                                                .foregroundStyle(.cyan)
                                        }
                                        Text(app.displayName)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Color(hex: app.textColorHex))
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.12)))
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(height: 150)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Navigateur du Catalogue Préconfiguré
struct CatalogBrowserView: View {
    @ObservedObject var store: SharedConfigurationStore
    var onSelectApp: ((LauncherApplication) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String = PredefinedAppsDatabase.categories.first ?? "Apple & Système"
    @State private var searchText = ""

    private var filteredApps: [PredefinedApp] {
        let inCat = PredefinedAppsDatabase.all.filter { app in
            searchText.isEmpty ? (app.category == selectedCategory) : true
        }
        if searchText.isEmpty {
            return inCat
        }
        return inCat.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.urlScheme.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if searchText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PredefinedAppsDatabase.categories, id: \.self) { cat in
                                Button {
                                    selectedCategory = cat
                                } label: {
                                    Text(cat)
                                        .font(.subheadline.weight(selectedCategory == cat ? .bold : .medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == cat ? Color.cyan : Color.white.opacity(0.1))
                                        .foregroundStyle(selectedCategory == cat ? .black : .white)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                }

                List {
                    ForEach(filteredApps) { predefined in
                        let isAlreadyInLibrary = store.library.contains(where: { $0.urlScheme == predefined.urlScheme })
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.cyan.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                Image(systemName: predefined.iconName)
                                    .font(.system(size: 18))
                                    .foregroundStyle(.cyan)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(predefined.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.white)
                                Text(predefined.urlScheme)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                let launcherApp = predefined.launcherApplication
                                if let onSelect = onSelectApp {
                                    onSelect(launcherApp)
                                    dismiss()
                                } else {
                                    store.addToLibrary(launcherApp)
                                }
                            } label: {
                                if isAlreadyInLibrary && onSelectApp == nil {
                                    Label("Ajouté", systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.green)
                                } else {
                                    Label("Ajouter", systemImage: "plus.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.cyan)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.cyan)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .searchable(text: $searchText, prompt: "Rechercher une application...")
            }
            .navigationTitle("Catalogue d'apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tout importer") {
                        store.addBulkToLibrary(PredefinedAppsDatabase.defaultLibrary)
                    }
                    .font(.caption)
                    .foregroundStyle(.cyan)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Ajout d'une application personnalisée
struct AddCustomAppView: View {
    let onAdd: (LauncherApplication) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var urlScheme = ""
    @State private var selectedSymbol = "app.fill"
    @State private var textColor = Color.white
    @State private var testResult: String?

    private let symbols = [
        "app.fill", "globe", "star.fill", "bolt.fill", "heart.fill",
        "bell.fill", "bookmark.fill", "camera.fill", "music.note", "flame.fill",
        "gamecontroller.fill", "cart.fill", "bag.fill", "message.fill", "phone.fill",
        "gear", "folder.fill", "terminal.fill", "paperplane.fill", "waveform"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Détails de l'application") {
                    TextField("Nom affiché (ex: Mon Raccourci)", text: $name)
                    TextField("URL Scheme (ex: shortcuts://)", text: $urlScheme)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Icône SF Symbol") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(symbols, id: \.self) { symbol in
                            Button {
                                selectedSymbol = symbol
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedSymbol == symbol ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: symbol)
                                        .font(.system(size: 20))
                                        .foregroundStyle(selectedSymbol == symbol ? .cyan : .white)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Couleur du texte") {
                    ColorPicker("Couleur", selection: $textColor, supportsOpacity: false)
                }

                Section {
                    Button {
                        testURLScheme()
                    } label: {
                        Label("Tester l'URL Scheme maintenant", systemImage: "play.circle.fill")
                    }
                    .disabled(urlScheme.trimmingCharacters(in: .whitespaces).isEmpty)

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("Erreur") ? .red : .green)
                    }
                } footer: {
                    Text("Assurez-vous que l'application cible est bien installée sur votre iPhone pour que l'URL Scheme s'ouvre.")
                }
            }
            .navigationTitle("App personnalisée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        var finalScheme = urlScheme.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !finalScheme.contains("://") && !finalScheme.contains(":") {
                            finalScheme = "\(finalScheme)://"
                        }
                        let app = LauncherApplication(
                            displayName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            urlScheme: finalScheme,
                            symbolName: selectedSymbol,
                            textColorHex: textColor.hexString()
                        )
                        onAdd(app)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || urlScheme.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func testURLScheme() {
        var finalScheme = urlScheme.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalScheme.contains("://") && !finalScheme.contains(":") {
            finalScheme = "\(finalScheme)://"
        }
        guard let url = URL(string: finalScheme) else {
            testResult = "Erreur: URL invalide"
            return
        }
        UIApplication.shared.open(url) { success in
            if success {
                testResult = "Succès: Application ouverte !"
            } else {
                testResult = "Erreur: Impossible d'ouvrir cette URL"
            }
        }
    }
}

// MARK: - Vue Gestion de la Bibliothèque
private struct LibraryView: View {
    @ObservedObject var store: SharedConfigurationStore
    @State private var showingAddLookup = false
    @State private var showingBulk = false
    @State private var showingCatalog = false
    @State private var showingCustomApp = false
    @State private var searchText = ""

    private var filteredLibrary: [LauncherApplication] {
        if searchText.isEmpty { return store.library }
        return store.library.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.urlScheme.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    showingCatalog = true
                } label: {
                    Label("Ajouter depuis le catalogue (35+ apps)", systemImage: "sparkles.rectangle.stack.fill")
                        .foregroundStyle(.cyan)
                }

                Button {
                    showingCustomApp = true
                } label: {
                    Label("Ajouter une app personnalisée", systemImage: "link.badge.plus")
                }

                Button {
                    showingAddLookup = true
                } label: {
                    Label("Rechercher sur l'App Store / iTunes", systemImage: "icloud.and.arrow.down.fill")
                }

                Button {
                    showingBulk = true
                } label: {
                    Label("Importation en lot d'identifiants App Store", systemImage: "square.and.arrow.down.on.square.fill")
                }
            }

            Section("Applications enregistrées (\(store.library.count))") {
                if filteredLibrary.isEmpty {
                    Text("Aucune application trouvée.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredLibrary) { app in
                        SelectedApplicationRow(app: app, store: store)
                    }
                    .onDelete(perform: store.deleteFromLibrary)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Filtrer la bibliothèque...")
        .navigationTitle("Bibliothèque")
        .sheet(isPresented: $showingCatalog) {
            CatalogBrowserView(store: store)
        }
        .sheet(isPresented: $showingCustomApp) {
            AddCustomAppView { store.addToLibrary($0) }
        }
        .sheet(isPresented: $showingAddLookup) {
            AddAppLookupView { store.addToLibrary($0) }
        }
        .sheet(isPresented: $showingBulk) {
            BulkImportView(store: store)
        }
    }
}

// MARK: - Sélection depuis la Bibliothèque pour une Pile
private struct AddFromLibraryView: View {
    @ObservedObject var store: SharedConfigurationStore
    let selectedIds: Set<UUID>
    let onAdd: (LauncherApplication) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [LauncherApplication] {
        if searchText.isEmpty { return store.library }
        return store.library.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.urlScheme.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { app in
                    let isSelected = selectedIds.contains(app.id)
                    Button {
                        if !isSelected {
                            onAdd(app)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            AppIconPreview(app: app)
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.displayName)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.white)
                                Text(app.urlScheme)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                .foregroundStyle(isSelected ? .gray : .cyan)
                        }
                    }
                    .disabled(isSelected)
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher...")
            .navigationTitle("Ajouter à la pile")
            .toolbar {
                Button("Fermer") { dismiss() }
            }
        }
    }
}

// MARK: - Recherche App Store via iTunes API
private struct AddAppLookupView: View {
    let onAdd: (LauncherApplication) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Bool
    private let lookupService = ITunesAppLookupService()
    
    var body: some View { 
        NavigationStack { 
            List { 
                Section { 
                    TextField("Collez une URL App Store ou un identifiant (ex: 324684580)", text: $input)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField)
                        .submitLabel(.search)
                        .onSubmit { Task { await lookupAndAdd() } }

                    Button {
                        Task { await lookupAndAdd() }
                    } label: { 
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Rechercher sur l'iTunes API", systemImage: "icloud.and.arrow.down.fill")
                        }
                    }
                    .disabled(isLoading || ITunesAppLookupService.extractAppStoreId(from: input).isEmpty)
                } footer: {
                    Text(errorMessage ?? "L'icône officielle sera téléchargée, compressée et partagée automatiquement avec les widgets.")
                }
            }
            .navigationTitle("Recherche App Store")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
            }
        } 
    }
    
    private func lookupAndAdd() async { 
        focusedField = false
        isLoading = true
        errorMessage = nil
        do {
            let app = try await lookupService.lookup(input: input)
            onAdd(app)
            dismiss()
        } catch {
            errorMessage = "Impossible de récupérer les détails de l'application. Vérifiez l'ID ou l'URL."
        }
        isLoading = false 
    }
}

// MARK: - Importation en lot
private struct BulkImportView: View {
    @ObservedObject var store: SharedConfigurationStore
    @Environment(\.dismiss) private var dismiss
    @State private var idsText = ""
    @State private var isImporting = false
    @FocusState private var editorFocused: Bool
    private let lookupService = ITunesAppLookupService()

    var body: some View {
        NavigationStack {
            List {
                Section("Identifiants App Store (séparés par virgules ou retours à la ligne)") {
                    TextEditor(text: $idsText)
                        .frame(minHeight: 180)
                        .focused($editorFocused)
                }
                Section {
                    Button {
                        Task { await importApps() }
                    } label: {
                        if isImporting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Importer les applications")
                        }
                    }
                    .disabled(isImporting || idsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Import en lot")
            .toolbar {
                Button("Fermer") { dismiss() }
            }
        }
    }

    private func importApps() async {
        editorFocused = false
        isImporting = true
        let results = await lookupService.bulkLookup(idsText: idsText)
        store.addBulkToLibrary(results)
        isImporting = false
        dismiss()
    }
}

// MARK: - Ligne d'une application sélectionnée
private struct SelectedApplicationRow: View {
    let app: LauncherApplication
    @ObservedObject var store: SharedConfigurationStore
    @State private var textColor: Color

    init(app: LauncherApplication, store: SharedConfigurationStore) {
        self.app = app
        self.store = store
        _textColor = State(initialValue: Color(hex: app.textColorHex))
    }

    var body: some View {
        HStack(spacing: 12) {
            AppIconPreview(app: app)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(textColor)
                Text(app.urlScheme)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            ColorPicker("Couleur texte", selection: $textColor, supportsOpacity: false)
                .labelsHidden()
        }
        .padding(.vertical, 3)
        .onChange(of: textColor) { _, newValue in
            var updated = app
            updated.textColorHex = newValue.hexString()
            store.updateLibraryApp(updated)
        }
    }
}

// MARK: - Prévisualisation d'icône d'app
private struct AppIconPreview: View {
    let app: LauncherApplication

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.cyan.opacity(0.18))
                    Image(systemName: app.symbolName.isEmpty ? "app.fill" : app.symbolName)
                        .font(.system(size: 16))
                        .foregroundStyle(.cyan)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func loadImage() -> UIImage? {
        guard let fileName = app.iconFileName,
              let directory = try? SharedIconStorage.iconsDirectoryURL() else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path)
    }
}

// MARK: - Écran de Diagnostics et Tests
private struct DiagnosticView: View {
    @ObservedObject var store: SharedConfigurationStore
    @State private var logContent: String = AppGroupLogger.read()
    @State private var showingCopiedAlert = false

    private var containerPath: String {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.path ?? "Non disponible"
    }

    var body: some View {
        List {
            Section("État du conteneur App Group") {
                LabeledContent("Identifiant", value: appGroupIdentifier)
                LabeledContent("Piles actives", value: "\(store.configurations.count)")
                LabeledContent("Apps enregistrées", value: "\(store.library.count)")
                LabeledContent("Chemin conteneur", value: containerPath.split(separator: "/").suffix(3).joined(separator: "/"))
            }

            Section("Actions de synchronisation") {
                Button {
                    store.forceReload()
                    logContent = AppGroupLogger.read()
                } label: {
                    Label("Forcer la synchronisation et recharger les widgets", systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    store.seedDefaults()
                    logContent = AppGroupLogger.read()
                } label: {
                    Label("Réinitialiser les applications et favoris", systemImage: "arrow.counterclockwise")
                        .foregroundStyle(.orange)
                }
            }

            Section("Journal d'événements (Logs)") {
                ScrollView {
                    Text(logContent)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .frame(minHeight: 180)
            }
        }
        .navigationTitle("Diagnostics")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Rafraîchir") {
                    logContent = AppGroupLogger.read()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Purger", role: .destructive) {
                    AppGroupLogger.clear()
                    logContent = AppGroupLogger.read()
                }
            }
        }
    }
}