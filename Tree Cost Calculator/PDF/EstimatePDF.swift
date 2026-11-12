//
//  EstimatePDF.swift
//  Tree Cost Calculator
//

import UIKit
import CoreText

/// Lays out a customer-facing estimate or invoice as a multi-page PDF (Letter in North America, A4 elsewhere).
/// Stays on the main actor because `Format` is main-actor isolated.
final class EstimatePDF {
    private let estimate: Estimate
    private let business: BusinessProfile
    private let logo: UIImage?

    private let pageRect: CGRect
    private let margin: CGFloat = 48
    private let footerHeight: CGFloat = 30

    // Drawing state
    private var context: UIGraphicsPDFRendererContext!
    private var y: CGFloat = 0
    private var pageNumber = 0
    private var totalPages: Int?
    /// True during the page-counting pass: photos are drawn as placeholders so they are only decoded once.
    private var skipImages = false

    private var isInvoice: Bool { estimate.status.isInvoice }

    private var contentWidth: CGFloat { pageRect.width - margin * 2 }
    private var bottomLimit: CGFloat { pageRect.height - margin - footerHeight }
    private var units: UnitSystem { estimate.unitSystem }
    private let totals: EstimateTotals

    // Palette
    private let brand = UIColor(red: 0.118, green: 0.541, blue: 0.290, alpha: 1)
    private let ink = UIColor(red: 0.11, green: 0.16, blue: 0.13, alpha: 1)
    private let muted = UIColor(red: 0.40, green: 0.46, blue: 0.42, alpha: 1)
    private let hairline = UIColor(red: 0.86, green: 0.89, blue: 0.87, alpha: 1)
    private let tint = UIColor(red: 0.945, green: 0.965, blue: 0.950, alpha: 1)

    init(estimate: Estimate, business: BusinessProfile, logo: UIImage?) {
        self.estimate = estimate
        self.business = business
        self.logo = logo
        self.totals = estimate.totals
        // Letter paper is used across the Americas (and the Philippines); everywhere else uses A4.
        let letterRegions: Set<String> = ["US", "CA", "MX", "PR", "PH", "CL", "CO", "VE", "GT", "CR", "PA", "DO", "SV", "NI", "BO"]
        let usesLetter = Locale.current.region.map { letterRegions.contains($0.identifier) } ?? false
        self.pageRect = usesLetter ? CGRect(x: 0, y: 0, width: 612, height: 792) : CGRect(x: 0, y: 0, width: 595, height: 842)
    }

    /// Renders the PDF. Two passes: the first counts pages so the footer can say "Page 1 of 3".
    func render() -> Data {
        skipImages = true
        let (_, count) = draw(totalPages: nil)
        skipImages = false
        return draw(totalPages: count).data
    }

    // MARK: - Rendering

    private func draw(totalPages: Int?) -> (data: Data, pages: Int) {
        self.totalPages = totalPages
        pageNumber = 0

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "\(isInvoice ? "Invoice" : "Estimate") \(estimate.documentLabel)",
            kCGPDFContextCreator as String: "Tree Cost Calculator",
            kCGPDFContextAuthor as String: business.name.isEmpty ? "Tree Cost Calculator" : business.name
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let data = renderer.pdfData { ctx in
            context = ctx
            newPage()
            drawHeader()
            drawParties()
            drawTrees()
            drawLineItems()
            drawTotals()
            drawPayment()
            drawNotes()
            drawTerms()
            if isInvoice { drawAcceptedLine() } else { drawAcceptance() }
            drawPhotos()
            drawFooter()
        }
        context = nil
        return (data, pageNumber)
    }

    private func newPage() {
        if pageNumber > 0 { drawFooter() }
        context.beginPage()
        pageNumber += 1
        y = margin
    }

    private func ensureSpace(_ height: CGFloat) {
        if y + height > bottomLimit { newPage() }
    }

    // MARK: - Sections

    private func drawHeader() {
        let rightWidth: CGFloat = 200
        let leftWidth = contentWidth - rightWidth - 16
        var leftX = margin
        var leftHeight: CGFloat = 0

        if let logo {
            let maxH: CGFloat = 52, maxW: CGFloat = 120
            let scale = min(maxW / logo.size.width, maxH / logo.size.height, 1)
            let size = CGSize(width: logo.size.width * scale, height: logo.size.height * scale)
            logo.draw(in: CGRect(x: margin, y: y, width: size.width, height: size.height))
            leftX += size.width + 14
            leftHeight = size.height
        }

        var textY = y
        let textWidth = leftWidth - (leftX - margin)
        let name = business.name.isEmpty ? "Tree Removal Estimate" : business.name
        textY += drawText(name, x: leftX, y: textY, width: textWidth, font: .boldSystemFont(ofSize: 17), color: ink) + 3
        let contact = [business.phone, business.email].filter { !$0.isEmpty }.joined(separator: "  ·  ")
        if !contact.isEmpty {
            textY += drawText(contact, x: leftX, y: textY, width: textWidth, font: .systemFont(ofSize: 9.5), color: muted) + 2
        }
        if !business.address.isEmpty {
            textY += drawText(business.address, x: leftX, y: textY, width: textWidth, font: .systemFont(ofSize: 9.5), color: muted) + 2
        }
        if !estimate.licenseNumber.trimmed.isEmpty {
            textY += drawText("License no. \(estimate.licenseNumber.trimmed)", x: leftX, y: textY, width: textWidth, font: .systemFont(ofSize: 9.5, weight: .medium), color: muted) + 2
        }
        leftHeight = max(leftHeight, textY - y)

        // Right column
        let rightX = pageRect.width - margin - rightWidth
        var rightY = y
        let smallFont = UIFont.systemFont(ofSize: 9.5)
        rightY += drawText(isInvoice ? "INVOICE" : "ESTIMATE", x: rightX, y: rightY, width: rightWidth, font: .systemFont(ofSize: 24, weight: .heavy), color: brand, align: .right, kern: 1.5) + 2
        rightY += drawText(estimate.documentLabel, x: rightX, y: rightY, width: rightWidth, font: .systemFont(ofSize: 11, weight: .semibold), color: ink, align: .right) + 6
        if isInvoice {
            let invoiceDate = estimate.invoiceDate ?? estimate.updatedAt
            rightY += drawText("Invoice date: \(invoiceDate.formatted(date: .long, time: .omitted))", x: rightX, y: rightY, width: rightWidth, font: smallFont, color: muted, align: .right) + 2
            if business.invoiceDueDays > 0, let due = Calendar.current.date(byAdding: .day, value: business.invoiceDueDays, to: invoiceDate) {
                rightY += drawText("Payment due: \(due.formatted(date: .long, time: .omitted))", x: rightX, y: rightY, width: rightWidth, font: .systemFont(ofSize: 9.5, weight: .semibold), color: ink, align: .right)
            } else {
                rightY += drawText("Due on receipt", x: rightX, y: rightY, width: rightWidth, font: .systemFont(ofSize: 9.5, weight: .semibold), color: ink, align: .right)
            }
        } else {
            let date = estimate.createdAt.formatted(date: .long, time: .omitted)
            rightY += drawText("Date: \(date)", x: rightX, y: rightY, width: rightWidth, font: smallFont, color: muted, align: .right) + 2
            if business.validDays > 0, let until = Calendar.current.date(byAdding: .day, value: business.validDays, to: estimate.createdAt) {
                rightY += drawText("Valid until: \(until.formatted(date: .long, time: .omitted))", x: rightX, y: rightY, width: rightWidth, font: smallFont, color: muted, align: .right)
            }
        }

        y += max(leftHeight, rightY - y) + 14
        fill(CGRect(x: margin, y: y, width: contentWidth, height: 2.5), color: brand)
        y += 22
    }

    private func drawParties() {
        // The job name leads, so the customer sees what the document is about before who it is for.
        let job = estimate.title.trimmed
        if !job.isEmpty {
            y += drawText("JOB", x: margin, y: y, width: contentWidth, font: .systemFont(ofSize: 8, weight: .bold), color: muted, kern: 1) + 5
            y += drawText(job, x: margin, y: y, width: contentWidth, font: .boldSystemFont(ofSize: 14), color: ink) + 16
        }
        let hasCustomer = ![estimate.customerName, estimate.customerPhone, estimate.customerEmail].allSatisfy { $0.trimmed.isEmpty }
        let hasAddress = !estimate.address.trimmed.isEmpty
        guard hasCustomer || hasAddress else { return }

        let columnWidth = (contentWidth - 20) / 2
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0
        let startY = y

        if hasCustomer {
            var cy = startY
            cy += drawText("PREPARED FOR", x: margin, y: cy, width: columnWidth, font: .systemFont(ofSize: 8, weight: .bold), color: muted, kern: 1) + 5
            if !estimate.customerName.trimmed.isEmpty {
                cy += drawText(estimate.customerName.trimmed, x: margin, y: cy, width: columnWidth, font: .boldSystemFont(ofSize: 12), color: ink) + 2
            }
            for line in [estimate.customerPhone, estimate.customerEmail] where !line.trimmed.isEmpty {
                cy += drawText(line.trimmed, x: margin, y: cy, width: columnWidth, font: .systemFont(ofSize: 10), color: ink) + 2
            }
            leftHeight = cy - startY
        }
        if hasAddress {
            var cy = startY
            let x = margin + columnWidth + 20
            cy += drawText("JOB SITE", x: x, y: cy, width: columnWidth, font: .systemFont(ofSize: 8, weight: .bold), color: muted, kern: 1) + 5
            cy += drawText(estimate.address.trimmed, x: x, y: cy, width: columnWidth, font: .systemFont(ofSize: 10), color: ink) + 2
            rightHeight = cy - startY
        }
        y += max(leftHeight, rightHeight) + 22
    }

    private func drawTrees() {
        let measured = estimate.trees.filter(\.isMeasured)
        guard !measured.isEmpty else { return }

        drawSectionTitle("TREES")

        guard business.itemizeTrees else {
            let line = "\(measured.count) \(measured.count == 1 ? "tree" : "trees") · total volume \(Format.volume(totals.volume, in: units))"
            y += drawText(line, x: margin, y: y, width: contentWidth, font: .systemFont(ofSize: 10.5), color: ink) + 20
            return
        }

        let numberW: CGFloat = 26, circW: CGFloat = 92, heightW: CGFloat = 78, volumeW: CGFloat = 86
        let descW = contentWidth - numberW - circW - heightW - volumeW - 16
        let descX = margin + 8 + numberW
        let circX = descX + descW
        let heightX = circX + circW
        let volumeX = heightX + heightW

        func headerRow() {
            fill(CGRect(x: margin, y: y, width: contentWidth, height: 22), color: tint, radius: 5)
            let font = UIFont.systemFont(ofSize: 8, weight: .bold)
            drawText("#", x: margin + 8, y: y + 7, width: numberW, font: font, color: muted, kern: 0.6)
            drawText("DESCRIPTION", x: descX, y: y + 7, width: descW, font: font, color: muted, kern: 0.6)
            drawText("CIRCUMFERENCE", x: circX, y: y + 7, width: circW, font: font, color: muted, align: .right, kern: 0.6)
            drawText("HEIGHT", x: heightX, y: y + 7, width: heightW, font: font, color: muted, align: .right, kern: 0.6)
            drawText("VOLUME", x: volumeX, y: y + 7, width: volumeW - 8, font: font, color: muted, align: .right, kern: 0.6)
            y += 26
        }

        ensureSpace(60)
        headerRow()

        let font = UIFont.systemFont(ofSize: 10)
        // Numbered by position in the estimate, like the editor and the photo captions, even if a tree
        // without measurements is left out.
        let numbered = estimate.trees.enumerated().filter { $0.element.isMeasured }
        for (offset, (index, tree)) in numbered.enumerated() {
            let number = index + 1
            let description = tree.label.trimmed.isEmpty ? "Tree \(number)" : tree.label.trimmed
            let textHeight = measure(description, width: descW - 8, font: font)
            let rowHeight = max(24, textHeight + 12)
            if y + rowHeight > bottomLimit {
                newPage()
                headerRow()
            }
            if offset % 2 == 1 {
                fill(CGRect(x: margin, y: y, width: contentWidth, height: rowHeight), color: tint.withAlphaComponent(0.55), radius: 4)
            }
            let ty = y + (rowHeight - 12) / 2
            drawText("\(number)", x: margin + 8, y: ty, width: numberW, font: font, color: muted)
            drawText(description, x: descX, y: y + 6, width: descW - 8, font: font, color: ink)
            drawText(Format.length(tree.circumference, in: units), x: circX, y: ty, width: circW, font: font, color: ink, align: .right)
            drawText(Format.length(tree.height, in: units), x: heightX, y: ty, width: heightW, font: font, color: ink, align: .right)
            drawText(Format.volume(tree.volume, in: units), x: volumeX, y: ty, width: volumeW - 8, font: .systemFont(ofSize: 10, weight: .semibold), color: ink, align: .right)
            y += rowHeight
        }

        ensureSpace(44)
        y += 6
        line(from: CGPoint(x: margin, y: y), to: CGPoint(x: pageRect.width - margin, y: y))
        y += 8
        drawText("Total volume", x: circX - 40, y: y, width: circW + heightW + 40, font: .systemFont(ofSize: 10, weight: .semibold), color: ink, align: .right)
        drawText(Format.volume(totals.volume, in: units), x: volumeX, y: y, width: volumeW - 8, font: .systemFont(ofSize: 10, weight: .bold), color: ink, align: .right)
        y += 30
    }

    private func drawLineItems() {
        let items = estimate.lineItems.filter { $0.amount > 0 }
        guard !items.isEmpty else { return }

        drawSectionTitle("OTHER WORK")

        let qtyW: CGFloat = 96, priceW: CGFloat = 84, amountW: CGFloat = 86
        let descW = contentWidth - qtyW - priceW - amountW - 8
        let descX = margin + 8
        let qtyX = descX + descW
        let priceX = qtyX + qtyW
        let amountX = priceX + priceW

        func headerRow() {
            fill(CGRect(x: margin, y: y, width: contentWidth, height: 22), color: tint, radius: 5)
            let font = UIFont.systemFont(ofSize: 8, weight: .bold)
            drawText("DESCRIPTION", x: descX, y: y + 7, width: descW, font: font, color: muted, kern: 0.6)
            drawText("QUANTITY", x: qtyX, y: y + 7, width: qtyW, font: font, color: muted, align: .right, kern: 0.6)
            drawText("UNIT PRICE", x: priceX, y: y + 7, width: priceW, font: font, color: muted, align: .right, kern: 0.6)
            drawText("AMOUNT", x: amountX, y: y + 7, width: amountW - 8, font: font, color: muted, align: .right, kern: 0.6)
            y += 26
        }

        ensureSpace(60)
        headerRow()

        let font = UIFont.systemFont(ofSize: 10)
        for (offset, item) in items.enumerated() {
            let description = item.displayName + (item.usesMinimum ? " (minimum charge)" : "")
            let quantity = Format.number(item.quantity) + (item.unit.trimmed.isEmpty ? "" : " " + item.unit.trimmed)
            let textHeight = max(measure(description, width: descW - 8, font: font), measure(quantity, width: qtyW - 8, font: font))
            let rowHeight = max(24, textHeight + 12)
            if y + rowHeight > bottomLimit {
                newPage()
                headerRow()
            }
            if offset % 2 == 1 {
                fill(CGRect(x: margin, y: y, width: contentWidth, height: rowHeight), color: tint.withAlphaComponent(0.55), radius: 4)
            }
            drawText(description, x: descX, y: y + 6, width: descW - 8, font: font, color: ink)
            drawText(quantity, x: qtyX, y: y + 6, width: qtyW - 8, font: font, color: ink, align: .right)
            drawText(Format.unitPrice(item.unitPrice), x: priceX, y: y + 6, width: priceW - 8, font: font, color: ink, align: .right)
            drawText(Format.money(item.amount), x: amountX, y: y + 6, width: amountW - 8, font: .systemFont(ofSize: 10, weight: .semibold), color: ink, align: .right)
            y += rowHeight
        }
        y += 6
        line(from: CGPoint(x: margin, y: y), to: CGPoint(x: pageRect.width - margin, y: y))
        y += 22
    }

    private func drawTotals() {
        // Build the lines first so we know how tall the block is.
        var rows: [(label: String, value: String, style: RowStyle)] = []
        if totals.volume > 0 {
            rows.append(("Tree removal (\(Format.volume(totals.volume, in: units)) × \(Format.unitPrice(estimate.ratePerUnit)))", Format.money(totals.volumeCost), .normal))
        }
        if totals.startingFee > 0 { rows.append(("Starting fee", Format.money(totals.startingFee), .normal)) }
        if totals.lineItems > 0 { rows.append(("Other work", Format.money(totals.lineItems), .normal)) }
        if totals.surcharge > 0 {
            let label = estimate.surchargeLabel.trimmed.isEmpty ? "Additional charge" : estimate.surchargeLabel.trimmed
            rows.append((label, Format.money(totals.surcharge), .normal))
        }
        if totals.discount > 0 || totals.tax > 0 { rows.append(("Subtotal", Format.money(totals.subtotal), .bold)) }
        if totals.discount > 0 {
            let label = estimate.discount.kind == .percent ? "Discount (\(Format.percent(estimate.discount.amount)))" : "Discount"
            rows.append((label, "−" + Format.money(totals.discount), .discount))
        }
        if totals.tax > 0 { rows.append((Format.taxTitle(for: estimate), Format.money(totals.tax), .normal)) }

        let blockWidth = min(contentWidth, 340)
        let blockX = pageRect.width - margin - blockWidth
        let valueWidth: CGFloat = 90
        let labelWidth = blockWidth - valueWidth - 8
        let font = UIFont.systemFont(ofSize: 10.5)

        let rowHeights = rows.map { max(18, measure($0.label, width: labelWidth, font: font) + 6) }
        let isPaid = estimate.status == .paid
        let paidAmount = isPaid ? max(totals.paid, totals.total) : totals.paid
        let balance = isPaid ? 0 : max(0, totals.balanceDue)
        var needed = rowHeights.reduce(0, +) + 60
        if isInvoice { needed += 64 + (paidAmount > 0 ? 24 : 0) }
        else if totals.deposit > 0 { needed += 24 }
        ensureSpace(needed)

        for (index, row) in rows.enumerated() {
            let boldFont = UIFont.systemFont(ofSize: 10.5, weight: .semibold)
            let f = row.style == .bold ? boldFont : font
            let color = row.style == .discount ? UIColor(red: 0.80, green: 0.42, blue: 0.05, alpha: 1) : ink
            drawText(row.label, x: blockX, y: y + 2, width: labelWidth, font: f, color: row.style == .normal ? muted : color)
            drawText(row.value, x: blockX + blockWidth - valueWidth, y: y + 2, width: valueWidth, font: f, color: color, align: .right)
            y += rowHeights[index]
        }

        y += 8
        let totalRect = CGRect(x: blockX, y: y, width: blockWidth, height: 38)
        fill(totalRect, color: brand, radius: 9)
        drawText("TOTAL", x: blockX + 14, y: y + 12, width: 100, font: .systemFont(ofSize: 11, weight: .bold), color: .white, kern: 1.2)
        drawText(Format.money(totals.total), x: blockX + blockWidth - 190 - 14, y: y + 9, width: 190, font: .systemFont(ofSize: 17, weight: .heavy), color: .white, align: .right)
        let totalY = y
        y += 38

        if isInvoice {
            y += 10
            if paidAmount > 0 {
                drawText("Amount paid", x: blockX, y: y + 2, width: labelWidth, font: font, color: muted)
                drawText("−" + Format.money(paidAmount), x: blockX + blockWidth - valueWidth, y: y + 2, width: valueWidth, font: font, color: ink, align: .right)
                y += 24
            }
            // Highlighted box (outlined rather than filled so it reads as "what's left to pay").
            let balanceRect = CGRect(x: blockX, y: y, width: blockWidth, height: 38)
            fill(balanceRect, color: tint, radius: 9)
            let outline = UIBezierPath(roundedRect: balanceRect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: 9)
            outline.lineWidth = 1.5
            brand.setStroke()
            outline.stroke()
            drawText("BALANCE DUE", x: blockX + 14, y: y + 12, width: 120, font: .systemFont(ofSize: 11, weight: .bold), color: brand, kern: 1.2)
            drawText(Format.money(balance), x: blockX + blockWidth - 190 - 14, y: y + 9, width: 190, font: .systemFont(ofSize: 17, weight: .heavy), color: brand, align: .right)
            if isPaid { drawPaidStamp(centeredAt: CGPoint(x: margin + 70, y: (totalY + y + 38) / 2)) }
            y += 38 + 26
        } else if totals.deposit > 0 {
            y += 10
            var text = "Deposit due on acceptance: \(Format.money(totals.deposit))"
            if estimate.deposit.kind == .percent, estimate.deposit.amount > 0 { text += " (\(Format.percent(estimate.deposit.amount)))" }
            drawText(text, x: blockX, y: y, width: blockWidth, font: .systemFont(ofSize: 10.5, weight: .semibold), color: ink, align: .right)
            y += 14 + 26
        } else {
            y += 26
        }
    }

    /// A tilted "PAID" mark in the brand colour, like a rubber stamp.
    private func drawPaidStamp(centeredAt center: CGPoint) {
        let cg = context.cgContext
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y)
        cg.rotate(by: -8 * .pi / 180)
        let rect = CGRect(x: -52, y: -22, width: 104, height: 44)
        let border = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        border.lineWidth = 3
        brand.setStroke()
        border.stroke()
        drawText("PAID", x: rect.minX, y: rect.minY + 7, width: rect.width, font: .systemFont(ofSize: 24, weight: .heavy), color: brand, align: .center, kern: 3)
        cg.restoreGState()
    }

    private enum RowStyle { case normal, bold, discount }

    private func drawPayment() {
        guard isInvoice, !business.paymentInstructions.isEmpty else { return }
        ensureSpace(70)
        drawSectionTitle("PAYMENT")
        drawFlowingText(business.paymentInstructions, font: .systemFont(ofSize: 10.5), color: ink, lineSpacing: 2)
        y += 14
    }

    private func drawNotes() {
        let notes = estimate.notes.trimmed
        guard !notes.isEmpty else { return }
        ensureSpace(60)
        drawSectionTitle("NOTES")
        drawFlowingText(notes, font: .systemFont(ofSize: 10.5), color: ink, lineSpacing: 2)
        y += 14
    }

    private func drawTerms() {
        var parts: [String] = []
        if !isInvoice, business.validDays > 0 {
            parts.append("This estimate is valid for \(business.validDays) \(business.validDays == 1 ? "day" : "days") from the date above.")
        }
        if !business.terms.isEmpty { parts.append(business.terms) }
        guard !parts.isEmpty else { return }
        ensureSpace(60)
        drawSectionTitle("TERMS")
        drawFlowingText(parts.joined(separator: " "), font: .systemFont(ofSize: 8.5), color: muted, lineSpacing: 1.5)
        y += 22
    }

    /// Invoices don't need signature lines, but a signature collected on the estimate is kept as a record.
    private func drawAcceptedLine() {
        guard estimate.isSigned || estimate.signedAt != nil else { return }
        ensureSpace(80)
        y += 4
        var text = "Accepted"
        if !estimate.signedName.trimmed.isEmpty { text += " by \(estimate.signedName.trimmed)" }
        if let signedAt = estimate.signedAt { text += " on \(signedAt.formatted(date: .long, time: .omitted))" }
        y += drawText(text, x: margin, y: y, width: contentWidth, font: .systemFont(ofSize: 9), color: muted) + 4
        if let image = signatureImage() {
            let rect = aspectFitRect(for: image.size, in: CGRect(x: margin, y: y, width: 160, height: 36))
            image.draw(in: rect)
            y += 40
        }
        y += 10
    }

    private func signatureImage() -> UIImage? {
        guard !skipImages, let id = estimate.signatureID else { return nil }
        return PhotoStore.image(for: id, maxPixel: 900)
    }

    private func aspectFitRect(for size: CGSize, in box: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return box }
        let scale = min(box.width / size.width, box.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        // Bottom-aligned so the signature sits on the line.
        return CGRect(x: box.minX, y: box.maxY - fitted.height, width: fitted.width, height: fitted.height)
    }

    private func drawAcceptance() {
        let contractor = business.name.isEmpty ? "the contractor" : business.name
        let statement = "By signing below, the customer accepts this estimate and the terms stated on it and authorizes \(contractor) to perform the work described."
        let statementHeight = measure(statement, width: contentWidth, font: .systemFont(ofSize: 9))
        ensureSpace(statementHeight + 160)
        y += 16
        drawSectionTitle("ACCEPTANCE")
        y += drawText(statement, x: margin, y: y, width: contentWidth, font: .systemFont(ofSize: 9), color: muted) + 50

        let gap: CGFloat = 24
        let left = contentWidth * 0.62
        let rightX = margin + left + gap
        let rightWidth = contentWidth - left - gap
        let labelFont = UIFont.systemFont(ofSize: 8)
        let valueFont = UIFont.systemFont(ofSize: 10)

        // Signature image sits on the first line; the date and printed name are filled in if known.
        if let image = signatureImage() {
            let box = CGRect(x: margin, y: y - 46, width: left, height: 44)
            image.draw(in: aspectFitRect(for: image.size, in: box))
        }
        if let signedAt = estimate.signedAt {
            drawText(signedAt.formatted(date: .abbreviated, time: .omitted), x: rightX, y: y - 15, width: rightWidth, font: valueFont, color: ink)
        }

        line(from: CGPoint(x: margin, y: y), to: CGPoint(x: margin + left, y: y))
        line(from: CGPoint(x: rightX, y: y), to: CGPoint(x: rightX + rightWidth, y: y))
        y += 4
        drawText("Customer signature", x: margin, y: y, width: left, font: labelFont, color: muted)
        drawText("Date", x: rightX, y: y, width: rightWidth, font: labelFont, color: muted)
        y += 38

        if !estimate.signedName.trimmed.isEmpty {
            drawText(estimate.signedName.trimmed, x: margin, y: y - 15, width: left, font: valueFont, color: ink)
        }
        line(from: CGPoint(x: margin, y: y), to: CGPoint(x: margin + left, y: y))
        line(from: CGPoint(x: rightX, y: y), to: CGPoint(x: rightX + rightWidth, y: y))
        y += 4
        drawText("Customer name (printed)", x: margin, y: y, width: left, font: labelFont, color: muted)
        drawText("Contractor signature", x: rightX, y: y, width: rightWidth, font: labelFont, color: muted)
        y += 30
    }

    private func drawPhotos() {
        guard business.includePhotos else { return }
        var items: [(id: UUID, caption: String)] = []
        for (index, tree) in estimate.trees.enumerated() {
            let name = tree.label.trimmed.isEmpty ? "Tree \(index + 1)" : "Tree \(index + 1) – \(tree.label.trimmed)"
            items += tree.photoIDs.map { ($0, name) }
        }
        items += estimate.sitePhotoIDs.map { ($0, "Site") }
        guard !items.isEmpty else { return }

        y += 8
        ensureSpace(190)
        drawSectionTitle("PHOTOS")

        let columns = 3
        let gap: CGFloat = 12
        let cellWidth = (contentWidth - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let cellHeight = cellWidth * 0.75
        let captionFont = UIFont.systemFont(ofSize: 8)
        let captionHeight = ceil(captionFont.lineHeight * 2)
        let rowHeight = cellHeight + 5 + captionHeight + 10

        for (index, item) in items.enumerated() {
            let column = index % columns
            if column == 0, index > 0 {
                y += rowHeight
            }
            if column == 0, y + rowHeight > bottomLimit {
                newPage()
            }
            let x = margin + CGFloat(column) * (cellWidth + gap)
            let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
            if !skipImages, let image = PhotoStore.image(for: item.id, maxPixel: 700) {
                drawAspectFill(image, in: rect, radius: 6)
            } else {
                fill(rect, color: tint, radius: 6)
            }
            drawTruncatedText(item.caption, in: CGRect(x: x, y: y + cellHeight + 5, width: cellWidth, height: captionHeight), font: captionFont, color: muted)
        }
        y += rowHeight
    }

    private func drawFooter() {
        let footerY = pageRect.height - margin + 4
        line(from: CGPoint(x: margin, y: footerY - 8), to: CGPoint(x: pageRect.width - margin, y: footerY - 8))
        let font = UIFont.systemFont(ofSize: 8)
        let left = business.name.isEmpty ? "Tree Cost Calculator" : business.name
        drawText(left, x: margin, y: footerY, width: contentWidth / 3, font: font, color: muted)
        drawText(estimate.documentLabel, x: margin + contentWidth / 3, y: footerY, width: contentWidth / 3, font: font, color: muted, align: .center)
        let page = totalPages.map { "Page \(pageNumber) of \($0)" } ?? "Page \(pageNumber)"
        drawText(page, x: margin + contentWidth * 2 / 3, y: footerY, width: contentWidth / 3, font: font, color: muted, align: .right)
    }

    private func drawSectionTitle(_ title: String) {
        y += drawText(title, x: margin, y: y, width: contentWidth, font: .systemFont(ofSize: 8.5, weight: .bold), color: brand, kern: 1.2) + 8
    }

    // MARK: - Primitives

    @discardableResult
    private func drawText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, font: UIFont, color: UIColor = .black,
                          align: NSTextAlignment = .left, kern: CGFloat = 0, lineSpacing: CGFloat = 0) -> CGFloat {
        let attributed = attributedString(text, font: font, color: color, align: align, kern: kern, lineSpacing: lineSpacing)
        let bounds = attributed.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let height = ceil(bounds.height)
        attributed.draw(with: CGRect(x: x, y: y, width: width, height: height), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return height
    }

    /// Draws at most two lines in a fixed box, ending with an ellipsis, so it can never run into what follows.
    private func drawTruncatedText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }

    /// Draws text that may be longer than the rest of the page, continuing on new pages as needed.
    /// CoreText tells us how many whole lines fit in the space left.
    private func drawFlowingText(_ text: String, font: UIFont, color: UIColor, lineSpacing: CGFloat) {
        let attributed = attributedString(text, font: font, color: color, align: .left, kern: 0, lineSpacing: lineSpacing)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let total = attributed.length
        let minimumHeight = ceil(font.lineHeight) * 2 + lineSpacing
        var location = 0
        while location < total {
            if bottomLimit - y < minimumHeight, y > margin { newPage() }
            var fitted = CFRange()
            CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: location, length: 0), nil,
                                                         CGSize(width: contentWidth, height: max(0, bottomLimit - y - 2)), &fitted)
            var length = fitted.length
            if length <= 0 {
                // Nothing fits (should only happen on an empty page); take a line's worth rather than loop forever.
                if y > margin { newPage(); continue }
                length = min(80, total - location)
            }
            let chunk = attributed.attributedSubstring(from: NSRange(location: location, length: length))
            // Trailing line breaks would add an empty line at the bottom of the chunk.
            var drawLength = chunk.length
            let chunkString = chunk.string as NSString
            while drawLength > 0, CharacterSet.newlines.contains(UnicodeScalar(chunkString.character(at: drawLength - 1)) ?? "a") { drawLength -= 1 }
            if drawLength > 0 {
                y += drawAttributed(chunk.attributedSubstring(from: NSRange(location: 0, length: drawLength)), x: margin, y: y, width: contentWidth)
            }
            location += length
            if location < total { newPage() }
        }
    }

    @discardableResult
    private func drawAttributed(_ attributed: NSAttributedString, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let bounds = attributed.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let height = ceil(bounds.height)
        attributed.draw(with: CGRect(x: x, y: y, width: width, height: height), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return height
    }

    private func measure(_ text: String, width: CGFloat, font: UIFont, lineSpacing: CGFloat = 0) -> CGFloat {
        let attributed = attributedString(text, font: font, color: .black, align: .left, kern: 0, lineSpacing: lineSpacing)
        return ceil(attributed.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
    }

    private func attributedString(_ text: String, font: UIFont, color: UIColor, align: NSTextAlignment, kern: CGFloat, lineSpacing: CGFloat) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style, .kern: kern])
    }

    private func fill(_ rect: CGRect, color: UIColor, radius: CGFloat = 0) {
        color.setFill()
        if radius > 0 {
            UIBezierPath(roundedRect: rect, cornerRadius: radius).fill()
        } else {
            UIBezierPath(rect: rect).fill()
        }
    }

    private func line(from: CGPoint, to: CGPoint) {
        let path = UIBezierPath()
        path.move(to: from)
        path.addLine(to: to)
        path.lineWidth = 0.6
        hairline.setStroke()
        path.stroke()
    }

    private func drawAspectFill(_ image: UIImage, in rect: CGRect, radius: CGFloat) {
        let cg = context.cgContext
        cg.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
        cg.restoreGState()
    }
}
