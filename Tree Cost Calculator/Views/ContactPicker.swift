//
//  ContactPicker.swift
//  Tree Cost Calculator
//

import SwiftUI
import Contacts
import ContactsUI

/// What the estimate needs from an address-book entry.
struct ImportedContact {
    var name: String
    var phone: String
    var email: String
    var address: String

    init(_ contact: CNContact) {
        name = CNContactFormatter.string(from: contact, style: .fullName)?.trimmed ?? ""
        phone = contact.phoneNumbers.first?.value.stringValue.trimmed ?? ""
        email = (contact.emailAddresses.first?.value as String?)?.trimmed ?? ""
        if let postal = contact.postalAddresses.first?.value {
            // Single line, because the estimate has one address field.
            address = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
                .replacingOccurrences(of: "\n", with: ", ")
                .trimmed
        } else {
            address = ""
        }
    }
}

/// The system contact picker. It runs out of process and hands back only the contact the user taps,
/// so the app needs no Contacts permission.
struct ContactPicker: UIViewControllerRepresentable {
    let onPick: (ImportedContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (ImportedContact) -> Void
        init(onPick: @escaping (ImportedContact) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onPick(ImportedContact(contact))
        }
    }
}
