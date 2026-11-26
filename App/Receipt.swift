import SwiftUI
import UIKit
import Vision
import VisionKit

/// Reads a receipt photo on the iPhone (Vision text recognition): the total, the shop and the date.
enum ReceiptReader {
    struct Result { var amount: Double?; var merchant: String; var date: Date? }

    static func read(_ image: UIImage) async -> Result {
        let lines = await recognize(image)
        return parse(lines)
    }

    static func recognize(_ image: UIImage) async -> [String] {
        guard let cg = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let req = VNRecognizeTextRequest()
                req.recognitionLevel = .accurate
                req.usesLanguageCorrection = true
                if let langs = try? req.supportedRecognitionLanguages() {
                    let wanted = ["en-US", "ar-SA"].filter { langs.contains($0) }
                    if !wanted.isEmpty { req.recognitionLanguages = wanted }
                }
                let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation)
                try? handler.perform([req])
                let lines = req.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
                cont.resume(returning: lines)
            }
        }
    }

    private static let numberRE = try! NSRegularExpression(pattern: "[0-9]{1,3}(?:,[0-9]{3})+(?:\\.[0-9]{1,3})?|[0-9]+(?:\\.[0-9]{1,3})?")
    private static let dateRE = try! NSRegularExpression(pattern: "\\b([0-3]?[0-9])[/.-]([01]?[0-9])[/.-]((?:20)?[0-9]{2})\\b")

    static func numbers(_ line: String) -> [Double] {
        let s = SMSParser.normalize(line)
        let ns = s as NSString
        return numberRE.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let raw = ns.substring(with: m.range)
            guard let v = Double(raw.replacingOccurrences(of: ",", with: "")), v > 0, v < 100_000 else { return nil }
            // whole numbers of 5+ digits are phone, invoice or card numbers, not prices
            if !raw.contains("."), raw.count >= 5 { return nil }
            return v
        }
    }

    static func parse(_ lines: [String]) -> Result {
        let clean = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        // 1) the line that says total (the strongest wording wins, the last one on the receipt among equals)
        let words: [(String, Int)] = [("grand total", 5), ("total due", 5), ("amount due", 5), ("net total", 4), ("الإجمالي", 4), ("الاجمالي", 4),
                                      ("المجموع", 3), ("net amount", 3), ("total", 2), ("المبلغ", 1), ("amount", 1)]
        var best: (score: Int, index: Int, value: Double)? = nil
        for (i, line) in clean.enumerated() {
            let low = line.lowercased()
            if low.contains("sub") || low.contains("vat") || low.contains("tax") || low.contains("change") || low.contains("الباقي") { continue }
            guard let w = words.first(where: { low.contains($0.0) }) else { continue }
            var nums = numbers(line)
            if nums.isEmpty, i + 1 < clean.count { nums = numbers(clean[i + 1]) }   // the amount is often on the next line
            guard let v = nums.max() else { continue }
            if best == nil || w.1 > best!.score || (w.1 == best!.score && i > best!.index) { best = (w.1, i, v) }
        }
        var amount = best?.value
        // 2) otherwise the largest price-looking number (with decimals)
        if amount == nil {
            amount = clean.flatMap { line in numbers(line).filter { $0 != $0.rounded() || line.contains(".") } }.max()
        }
        // shop: one of the first lines with real letters
        let skip = ["receipt", "invoice", "فاتورة", "ايصال", "إيصال", "welcome", "tel", "phone", "cr no", "vat"]
        let merchant = clean.prefix(6).first { line in
            let letters = line.filter(\.isLetter).count
            return letters >= 3 && letters * 2 >= line.count && !skip.contains { line.lowercased().contains($0) }
        } ?? ""
        // date: dd/mm/yyyy, the way receipts in Qatar print it
        var date: Date? = nil
        for line in clean {
            let s = SMSParser.normalize(line)
            let ns = s as NSString
            guard let m = dateRE.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { continue }
            guard let d = Int(ns.substring(with: m.range(at: 1))), let mo = Int(ns.substring(with: m.range(at: 2))),
                  var y = Int(ns.substring(with: m.range(at: 3))), (1...31).contains(d), (1...12).contains(mo) else { continue }
            if y < 100 { y += 2000 }
            if let found = Calendar.current.date(from: DateComponents(year: y, month: mo, day: d, hour: 12)), found <= Date() {
                date = found
                break
            }
        }
        return Result(amount: amount, merchant: String(merchant.prefix(40)), date: date)
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// The system document camera (finds the receipt's edges and flattens it).
struct DocumentScanner: UIViewControllerRepresentable {
    let onScan: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (UIImage?) -> Void
        init(onScan: @escaping (UIImage?) -> Void) { self.onScan = onScan }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onScan(scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil)
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { onScan(nil) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { onScan(nil) }
    }
}
