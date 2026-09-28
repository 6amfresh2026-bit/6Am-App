import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../domain/service/grocery_list_parser.dart';
import 'scan_matcher.dart';

/// Reads one captured photo with three on-device ML Kit models and turns every
/// signal into a search term the catalogue can be queried with:
///
///  • **barcodes** — the encoded value (confidence 1.0);
///  • **text** — brand names printed on packaging and hand-written list lines,
///    cleaned by [GroceryListParser] (confidence 0.9 — printed text is
///    reliable); and
///  • **image labels** — generic categories like "Banana"/"Bottle" for produce
///    with no text (confidence = the model's own score).
///
/// Nothing here decides availability — it only produces terms. Matching against
/// the real catalogue happens in [ScanMatcher.matchDetections].
class ImageScanAnalyzer {
  /// Ignore labels the model isn't at least this sure about.
  static const double _minLabelConfidence = 0.6;

  Future<List<ScanCandidate>> analyze(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final candidates = <ScanCandidate>[];

    // Barcodes.
    final barcodeScanner = BarcodeScanner();
    try {
      for (final b in await barcodeScanner.processImage(input)) {
        final value = (b.rawValue ?? b.displayValue)?.trim();
        if (value != null && value.isNotEmpty) {
          candidates.add(ScanCandidate(value, 1.0));
        }
      }
    } finally {
      await barcodeScanner.close();
    }

    // Text (brand names / list items).
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text = await recognizer.processImage(input);
      for (final name in GroceryListParser.parse(text.text)) {
        candidates.add(ScanCandidate(name, 0.9));
      }
    } finally {
      await recognizer.close();
    }

    // Generic image labels (produce).
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: _minLabelConfidence),
    );
    try {
      for (final label in await labeler.processImage(input)) {
        candidates.add(ScanCandidate(label.label, label.confidence));
      }
    } finally {
      await labeler.close();
    }

    return candidates;
  }
}
