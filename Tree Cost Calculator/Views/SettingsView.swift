//
//  SettingsView.swift
//  Tree Cost Calculator
//

import SwiftUI
import PhotosUI

enum AppLinks {
    static let support = URL(string: "https://rshamilton.github.io/treecostcalculator/support")!
    static let privacy = URL(string: "https://rshamilton.github.io/treecostcalculator/privacy")!
    static let terms = URL(string: "https://rshamilton.github.io/treecostcalculator/terms")!
    static let supportEmail = "treecostcalculator@googlegroups.com"
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var launch: LaunchCoordinator

    @AppStorage(SettingsKey.companyName) private var companyName = ""
    @AppStorage(SettingsKey.companyPhone) private var companyPhone = ""
    @AppStorage(SettingsKey.companyEmail) private var companyEmail = ""
    @AppStorage(SettingsKey.companyAddress) private var companyAddress = ""
    @AppStorage(SettingsKey.companyLicense) private var companyLicense = ""
    @AppStorage(SettingsKey.taxRegions) private var regionList = TaxRegionList()

    @AppStorage(SettingsKey.startingFee) private var startingFee = 0.0
    @AppStorage(SettingsKey.ratePerUnit) private var ratePerUnit = 10.0
    @AppStorage(SettingsKey.taxRate) private var taxRate = 0.0
    @AppStorage(SettingsKey.useMetric) private var useMetric = false

    @AppStorage(SettingsKey.validDays) private var validDays = 30
    @AppStorage(SettingsKey.terms) private var terms = AppDefaults.defaultTerms
    @AppStorage(SettingsKey.includePhotos) private var includePhotos = true
    @AppStorage(SettingsKey.itemizeTrees) private var itemizeTrees = true

    @AppStorage(SettingsKey.iCloudBackup) private var iCloudBackup = true
    @State private var usage: DataFolder.Usage?
    @State private var lastBackup: Date?
    @State private var confirmRestore = false
    private let iCloudAvailable = BackupLocation.isAvailable

    @State private var path: [UUID] = []
    @State private var logo: UIImage?
    @State private var logoItem: PhotosPickerItem?
    @FocusState private var keyboardActive: Bool

    private var units: UnitSystem { useMetric ? .metric : .imperial }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                businessSection
                pricingSection
                regionsSection
                estimateSection
                dataSection
                helpSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { keyboardActive = false; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .fontWeight(.semibold)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                TaxRegionEditor(list: $regionList, id: id)
            }
            .task {
                logo = PhotoStore.loadLogo()
                await refreshDataInfo()
            }
            .onChange(of: logoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        let saved = await Task.detached { PhotoStore.saveLogo(data) }.value
                        if saved { logo = PhotoStore.loadLogo() }
                    }
                    logoItem = nil
                }
            }
        }
    }

    // MARK: Sections

    private var businessSection: some View {
        Section {
            HStack(spacing: 14) {
                Group {
                    if let logo {
                        Image(uiImage: logo)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "building.2.crop.circle")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.tertiary)
                            .padding(6)
                    }
                }
                .frame(width: 60, height: 60)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Company logo")
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $logoItem, matching: .images) {
                            Text(logo == nil ? "Add Logo" : "Change")
                                .font(.subheadline.weight(.medium))
                        }
                        if logo != nil {
                            Button("Remove", role: .destructive) {
                                PhotoStore.removeLogo()
                                logo = nil
                            }
                            .font(.subheadline)
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 2)

            IconField(symbol: "building.2.fill", placeholder: "Company name", text: $companyName)
                .textContentType(.organizationName)
                .textInputAutocapitalization(.words)
            IconField(symbol: "phone.fill", placeholder: "Phone", text: $companyPhone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
            IconField(symbol: "envelope.fill", placeholder: "Email", text: $companyEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            IconField(symbol: "mappin.and.ellipse", placeholder: "Address", text: $companyAddress)
                .textContentType(.fullStreetAddress)
            IconField(symbol: "checkmark.seal.fill", placeholder: "License number (if required)", text: $companyLicense)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        } header: {
            Text("Your Business")
        } footer: {
            Text("Shown at the top of every PDF estimate. If you work in more than one state, you can give each tax region its own license number below.")
        }
    }

    private var pricingSection: some View {
        Section {
            Picker("Measurements", selection: $useMetric) {
                Text("Feet").tag(false)
                Text("Meters").tag(true)
            }
            .pickerStyle(.segmented)

            LabeledContent("Starting fee") {
                NumberField(placeholder: "0", value: $startingFee, prefix: Format.currencySymbol)
            }
            LabeledContent("Price per \(units.volumeUnit)") {
                NumberField(placeholder: "0", value: $ratePerUnit, prefix: Format.currencySymbol)
            }
            LabeledContent("Tax rate") {
                NumberField(placeholder: "0", value: $taxRate, suffix: "%")
            }
        } header: {
            Text("Default Pricing")
        } footer: {
            Text("Used when you start a new estimate. Existing estimates keep the prices and units they were created with.")
        }
    }

    private var regionsSection: some View {
        Section {
            ForEach(regionList.items) { region in
                NavigationLink(value: region.id) {
                    HStack {
                        Text(region.name.trimmed.isEmpty ? "Unnamed region" : region.name)
                        Spacer()
                        Text(Format.percent(region.rate))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { regionList.items.remove(atOffsets: $0) }

            Button {
                let region = TaxRegion()
                regionList.items.append(region)
                path.append(region.id)
            } label: {
                Label("Add Tax Region", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Tax Regions")
        } footer: {
            Text("Working in more than one state or area? Add each one here, then choose it on an estimate to switch that estimate's tax rate and license number. You are responsible for entering the correct rates.")
        }
    }

    private var estimateSection: some View {
        Section {
            Picker("Valid for", selection: $validDays) {
                ForEach([7, 14, 30, 45, 60, 90], id: \.self) { days in
                    Text("\(days) days").tag(days)
                }
            }
            Toggle("Show each tree on the PDF", isOn: $itemizeTrees)
            Toggle("Include photos in the PDF", isOn: $includePhotos)

            VStack(alignment: .leading, spacing: 8) {
                Text("Terms")
                    .font(.subheadline.weight(.medium))
                TextField("Terms and conditions", text: $terms, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(3...8)
                if terms != AppDefaults.defaultTerms {
                    Button("Reset to default text") { terms = AppDefaults.defaultTerms }
                        .font(.footnote)
                        .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 2)
        } header: {
            Text("Estimate PDF")
        } footer: {
            Text("Printed on every estimate. Add any notices your state or local law requires (for example cancellation rights) and have a local attorney review your wording.")
        }
    }

    // MARK: Your data

    private func refreshDataInfo() async {
        usage = await Task.detached(priority: .utility) { DataFolder.usage() }.value
        lastBackup = UserDefaults.standard.object(forKey: SettingsKey.lastBackup) as? Date
    }

    private func sizeText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var dataFooter: String {
        let files = "Everything is saved as ordinary files in the “TCC” folder in the Files app, so you can see exactly what uses space."
        if !iCloudAvailable {
            return files + " Sign in to iCloud and turn on iCloud Drive to also back it up automatically."
        }
        if !iCloudBackup {
            return files + " Backup is off. An existing backup stays in iCloud Drive until you delete it there."
        }
        var text = files + " A copy is kept in your iCloud Drive automatically, so your estimates, photos and settings come back if you delete and reinstall the app. The copy uses your iCloud storage."
        if let lastBackup { text += " Last backup: \(lastBackup.formatted(date: .abbreviated, time: .shortened))." }
        return text
    }

    private var dataSection: some View {
        Section {
            Toggle("Back up to iCloud Drive", isOn: $iCloudBackup)
                .disabled(!iCloudAvailable)
                .onChange(of: iCloudBackup) { _, isOn in
                    if isOn { BackupScheduler.shared.schedule(after: 1) }
                }
            LabeledContent("Estimates") {
                Text(usage.map { "\($0.estimateCount) · \(sizeText($0.estimateBytes))" } ?? "…")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Photos") {
                Text(usage.map { "\($0.photoCount) · \(sizeText($0.photoBytes))" } ?? "…")
                    .foregroundStyle(.secondary)
            }
            Button {
                if let url = URL(string: "shareddocuments://" + DataFolder.root.path) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Show in Files", systemImage: "folder")
            }
            if iCloudAvailable {
                Button {
                    confirmRestore = true
                } label: {
                    Label("Restore from iCloud", systemImage: "icloud.and.arrow.down")
                }
                .confirmationDialog("Restore from iCloud?", isPresented: $confirmRestore, titleVisibility: .visible) {
                    Button("Restore") { launch.restoreFromBackup() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Brings back estimates and photos from your iCloud Drive backup that aren't on this device, and updates estimates that were changed on another device. Your settings are replaced by the ones in the backup. Nothing is deleted.")
                }
            }
        } header: {
            Text("Your Data")
        } footer: {
            Text(dataFooter)
        }
    }

    private var helpSection: some View {
        Section("Help") {
            Link(destination: AppLinks.support) {
                Label("Support & FAQ", systemImage: "lifepreserver")
            }
            if let mail = URL(string: "mailto:\(AppLinks.supportEmail)?subject=Tree%20Cost%20Calculator%20\(versionString)") {
                Link(destination: mail) {
                    Label("Email Support", systemImage: "envelope")
                }
            }
            Link(destination: AppLinks.privacy) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            Link(destination: AppLinks.terms) {
                Label("Terms of Use", systemImage: "doc.text")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: versionString)
        } footer: {
            Text("Prices, volumes, tax rates and every other figure in this app are calculated from what you enter and are estimates and examples only. They can be wrong or out of date. You are responsible for checking everything, and the app's maker accepts no responsibility or liability for estimates, jobs, taxes or data. See the Terms of Use.\n\nThe developer never receives your data.\n\n© 2026 Ryan Hamilton. All rights reserved.")
        }
    }
}

// MARK: - Tax region editor

struct TaxRegionEditor: View {
    @Binding var list: TaxRegionList
    let id: UUID

    @Environment(\.dismiss) private var dismiss

    private func binding<T>(_ keyPath: WritableKeyPath<TaxRegion, T>, fallback: T) -> Binding<T> {
        Binding(
            get: { list.items.first { $0.id == id }?[keyPath: keyPath] ?? fallback },
            set: { newValue in
                if let index = list.items.firstIndex(where: { $0.id == id }) {
                    list.items[index][keyPath: keyPath] = newValue
                }
            }
        )
    }

    private var region: TaxRegion? { list.items.first { $0.id == id } }

    var body: some View {
        Form {
            Section {
                TextField("State or area, e.g. Texas", text: binding(\.name, fallback: ""))
                    .textInputAutocapitalization(.words)
                LabeledContent("Tax rate") {
                    NumberField(placeholder: "0", value: binding(\.rate, fallback: 0), suffix: "%")
                }
            } footer: {
                Text("Used when you choose this region on an estimate.")
            }

            Section {
                IconField(symbol: "checkmark.seal.fill", placeholder: "License number (optional)", text: binding(\.license, fallback: ""))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            } header: {
                Text("License")
            } footer: {
                Text("Printed on estimates for this region. Leave empty to use your main license number.")
            }

            Section {
                Button("Delete Region", role: .destructive) {
                    list.items.removeAll { $0.id == id }
                    dismiss()
                }
            }
        }
        .navigationTitle(region?.name.trimmed.isEmpty == false ? region!.name : "Tax Region")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // A region that was added but never filled in isn't worth keeping.
            if let region, region.name.trimmed.isEmpty, region.rate == 0, region.license.trimmed.isEmpty {
                list.items.removeAll { $0.id == id }
            }
        }
    }
}

#Preview {
    SettingsView()
}
