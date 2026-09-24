import ServiceManagement
import SwiftUI
import SweepCore
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings() }
            Tab("Lifecycle", systemImage: "clock") { LifecycleSettings() }
            Tab("Rules", systemImage: "arrow.triangle.branch") { RuleSettings() }
            Tab("Pinned", systemImage: "pin") { PinnedSettings() }
            Tab("About", systemImage: "info.circle") { AboutSettings() }
        }
        .scenePadding()
        .frame(width: 560, height: 460)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @State private var choosingFolder = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Picker("When Downsweep finds something", selection: $model.settings.mode) {
                    Text("Ask me first").tag(SweepMode.review)
                    Text("Sweep automatically").tag(SweepMode.automatic)
                }
                .pickerStyle(.radioGroup)
            } footer: {
                Text("Automatic mode stops and asks before moving more than \(SafetyLimit.maxItems) items or \(SafetyLimit.maxBytes.fileSize) at once.")
                    .foregroundStyle(.secondary)
            }

            Section("Folder") {
                LabeledContent("Watching") {
                    HStack {
                        Text(model.settings.folderURL.lastPathComponent)
                        Button("Change…") { choosingFolder = true }
                    }
                }
            }

            Section("Detection") {
                Toggle("Find installers for apps that are already installed", isOn: $model.settings.configuration.detectInstallers)
                Toggle("Find duplicate downloads", isOn: $model.settings.configuration.detectDuplicates)
            }

            Section {
                Toggle("Open at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { model.settings.folderPath = url.path }
        }
    }
}

// MARK: - Lifecycle

private struct LifecycleSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                DayStepper(title: "Leave new downloads alone for", value: $model.settings.configuration.thresholds.newDays, range: 1...30)
                DayStepper(title: "Count as in use if opened within", value: $model.settings.configuration.thresholds.activeDays, range: 1...90)
                DayStepper(title: "Tag as Stale after not opening for", value: $model.settings.configuration.thresholds.staleDays, range: 7...365)
                DayStepper(title: "Move stale items to Trash after", value: $model.settings.configuration.thresholds.expireAfterStaleDays, range: 1...180)
            } footer: {
                Text("Stale items get a Finder tag first, so you can spot them before anything moves.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Restore Defaults") {
                    model.settings.configuration.thresholds = .default
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct DayStepper: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range) {
            LabeledContent(title) {
                Text("\(value) days")
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Rules

private struct RuleSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                ForEach($model.settings.configuration.rules) { $rule in
                    RuleRow(rule: $rule)
                }
                .onDelete { model.settings.configuration.rules.remove(atOffsets: $0) }
            } header: {
                Text("Move files downloaded from…")
            } footer: {
                HStack {
                    Text("Subdomains match too: “google.com” covers mail.google.com.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add Rule", systemImage: "plus") { addRule(domain: "") }
                }
            }

            if let hosts = model.result?.topSourceHosts.prefix(6), !hosts.isEmpty {
                Section("Common sources in your Downloads") {
                    ForEach(Array(hosts), id: \.host) { entry in
                        LabeledContent(entry.host) {
                            HStack {
                                Text("^[\(entry.count) file](inflect: true)").foregroundStyle(.secondary)
                                Button("Add Rule") { addRule(domain: entry.host) }
                                    .disabled(model.settings.configuration.rules.contains { $0.normalizedDomain == entry.host })
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func addRule(domain: String) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        model.settings.configuration.rules.append(
            SourceRule(domain: domain, destination: documents.appending(path: domain.isEmpty ? "Sorted" : domain))
        )
    }
}

private struct RuleRow: View {
    @Binding var rule: SourceRule
    @State private var choosingFolder = false

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Enabled", isOn: $rule.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            TextField("Domain", text: $rule.domain, prompt: Text("example.com"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 150)
            Image(systemName: "arrow.right")
                .foregroundStyle(.tertiary)
            Button {
                choosingFolder = true
            } label: {
                Label(rule.destination.lastPathComponent, systemImage: "folder")
                    .lineLimit(1)
            }
            .help(rule.destination.path(percentEncoded: false))
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { rule.destination = url }
        }
    }
}

// MARK: - Pinned

private struct PinnedSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let pinned = model.settings.configuration.pinned.sorted { $0.lastPathComponent < $1.lastPathComponent }
        Group {
            if pinned.isEmpty {
                ContentUnavailableView(
                    "Nothing Pinned",
                    systemImage: "pin",
                    description: Text("Pin an item in Review and Downsweep will never suggest it again.")
                )
            } else {
                Form {
                    Section("Never touch") {
                        ForEach(pinned, id: \.self) { url in
                            HStack {
                                FileIcon(url: url).frame(width: 20, height: 20)
                                Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Button("Unpin") { model.unpin(url) }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
    }
}
