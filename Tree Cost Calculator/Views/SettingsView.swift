//
//  SettingsView.swift
//  Tree Cost Calculator
//

import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var launch: LaunchCoordinator
    @EnvironmentObject private var store: EstimateStore

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

    @AppStorage(SettingsKey.services) private var services = ServiceList()
    @AppStorage(SettingsKey.invoiceDueDays) private var invoiceDueDays = 14
    @AppStorage(SettingsKey.paymentInstructions) private var paymentInstructions = ""

    @AppStorage(SettingsKey.iCloudBackup) private var iCloudBackup = true
    @State private var usage: DataFolder.Usage?
    @State private var lastBackup: Date?
    @State private var confirmRestore = false
    private let iCloudAvailable = BackupLocation.isAvailable

    // A mixed path: tax regions are pushed by id, Services and About by SettingsPage.
    @State private var path = NavigationPath()
    @State private var logo: UIImage?
    @State private var logoItem: PhotosPickerItem?
    @FocusState private var keyboardActive: Bool
    @State private var exportFile: ExportFile?
    @State private var exportFailed = false

    private var units: UnitSystem { useMetric ? .metric : .imperial }

    /// Cubic feet in a cubic meter, for converting the saved price when the unit changes.
    private static let cubicFeetPerCubicMeter = 35.3147

    /// Switching Feet/Meters also converts the default price, so "$10 per cu ft" doesn't silently become
    /// "$10 per m³" (35 times cheaper). Done in the setter, not `onChange`, so a settings restore that
    /// changes both values at once isn't converted twice.
    private var measurementBinding: Binding<Bool> {
        Binding(
            get: { useMetric },
            set: { newValue in
                guard newValue != useMetric else { return }
                let factor = Self.cubicFeetPerCubicMeter
                let converted = newValue ? ratePerUnit * factor : ratePerUnit / factor
                ratePerUnit = converted.roundedToCents
                useMetric = newValue
            }
        )
    }

    private var dueOptions: [Int] {
        var options = [0, 7, 14, 15, 30, 45, 60]
        if !options.contains(invoiceDueDays) { options.append(invoiceDueDays); options.sort() }
        return options
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                businessSection
                pricingSection
                servicesSection
                regionsSection
                estimateSection
                invoiceSection
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
            .navigationDestination(for: SettingsPage.self) { page in
                switch page {
                case .services: ServicesSettingsView()
                case .about: AboutView()
                }
            }
            .sheet(item: $exportFile) { file in
                ActivityShareSheet(url: file.url)
                    .ignoresSafeArea()
            }
            .alert("Couldn't Export", isPresented: $exportFailed) {
                Button("OK") {}
            } message: {
                Text("The estimates file couldn't be created. Check that your device has free space and try again.")
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
            Picker("Measurements", selection: measurementBinding) {
                Text("Feet").tag(false)
                Text("Meters").tag(true)
            }
            .pickerStyle(.segmented)

            LabeledContent("Starting fee") {
                NumberField(placeholder: "0", value: $startingFee, prefix: Format.currencySymbol, accessibilityLabel: "Starting fee")
            }
            LabeledContent("Price per \(units.volumeUnit)") {
                NumberField(placeholder: "0", value: $ratePerUnit, prefix: Format.currencySymbol, accessibilityLabel: "Price per \(units.volumeUnit)")
            }
            LabeledContent("Tax rate") {
                NumberField(placeholder: "0", value: $taxRate, suffix: "%", accessibilityLabel: "Default tax rate")
            }
        } header: {
            Text("Default Pricing")
        } footer: {
            Text("Used when you start a new estimate. Existing estimates keep the prices and units they were created with. Switching between feet and meters converts the price per volume for you.")
        }
    }

    private var servicesSection: some View {
        Section {
            NavigationLink(value: SettingsPage.services) {
                HStack {
                    Label("Services & Prices", systemImage: "wrench.and.screwdriver")
                    Spacer()
                    Text("\(services.items.count)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Services")
        } footer: {
            Text("Stump grinding, hauling, crew time and other work you can add to any estimate under Other Work.")
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

    private var invoiceSection: some View {
        Section {
            Picker("Payment due", selection: $invoiceDueDays) {
                ForEach(dueOptions, id: \.self) { days in
                    Text(days == 0 ? "Due on receipt" : "\(days) days").tag(days)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Payment instructions")
                    .font(.subheadline.weight(.medium))
                TextField("e.g. Check payable to…, Zelle, card on site", text: $paymentInstructions, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(2...6)
            }
            .padding(.vertical, 2)
        } header: {
            Text("Invoices")
        } footer: {
            Text("To turn an estimate into an invoice, open it and choose Create Invoice from the status menu.")
        }
    }

    // MARK: Your data

    private func refreshDataInfo() async {
        usage = await Task.detached(priority: .utility) { DataFolder.usage() }.value
        lastBackup = UserDefaults.standard.object(forKey: SettingsKey.lastBackup) as? Date
    }

    /// Writes every estimate to a spreadsheet file and opens the share sheet for it.
    private func exportCSV() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tree Cost Calculator Estimates.csv")
        do {
            try store.csv().write(to: url, atomically: true, encoding: .utf8)
            exportFile = ExportFile(url: url)
        } catch {
            exportFailed = true
        }
    }

    private func sizeText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var dataFooter: String {
        let files = "Everything is saved as ordinary files in the “TCC” folder in the Files app, so you can see exactly what uses space."
        if store.estimates.isEmpty { return files + " Export is available once you have an estimate." }
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
            Button(action: exportCSV) {
                Label("Export All Estimates (CSV)", systemImage: "tablecells")
                    .dimWhenDisabled()
            }
            .disabled(store.estimates.isEmpty)
            .accessibilityHint(store.estimates.isEmpty ? "Create an estimate first" : "Saves all your estimates as a spreadsheet")
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
        Section("Help & Feedback") {
            Link(destination: AppLinks.support) {
                Label("Support & FAQ", systemImage: "lifepreserver")
            }
            if let mail = supportMailURL {
                Link(destination: mail) {
                    Label("Email Support", systemImage: "envelope")
                }
            }
            Link(destination: AppLinks.issues) {
                Label("Suggest a Feature or Report a Bug", systemImage: "ladybug")
            }
            Link(destination: AppLinks.writeReview) {
                Label("Rate Tree Cost Calculator", systemImage: "star")
            }
            ShareLink(item: AppLinks.appStore, message: Text("A free tree removal estimate app for iPhone and iPad")) {
                Label("Share the App", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var supportMailURL: URL? {
        let subject = "Tree Cost Calculator \(AppLinks.versionString)"
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Tree%20Cost%20Calculator"
        return URL(string: "mailto:\(AppLinks.supportEmail)?subject=\(encoded)")
    }

    private var aboutSection: some View {
        Section {
            NavigationLink(value: SettingsPage.about) {
                LabeledContent("About", value: AppLinks.versionString)
            }
        } header: {
            Text("About")
        } footer: {
            Text("Prices, volumes, tax rates and every other figure in this app are calculated from what you enter and are estimates and examples only. They can be wrong or out of date. You are responsible for checking everything, and the app's maker accepts no responsibility or liability for estimates, jobs, taxes or data. See the Terms of Use.\n\nThe developer never receives your data.\n\n© 2026 Ryan Hamilton. Free and open-source software under the GNU GPL v3.")
        }
    }
}

/// Screens pushed from the Settings list.
private enum SettingsPage: Hashable {
    case services
    case about
}

/// A file ready to share (Identifiable so a sheet can present it).
private struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// The system share sheet for a file.
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
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
                    NumberField(placeholder: "0", value: binding(\.rate, fallback: 0), suffix: "%", accessibilityLabel: "Tax rate")
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
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    .fontWeight(.semibold)
            }
        }
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
