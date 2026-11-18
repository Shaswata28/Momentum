import 'category_meta.dart';
import 'transaction.dart';

class CategoryInference {
  /// Attempts to infer the most appropriate [ExpenseType] based on the input text.
  /// Returns `null` if no strong match is found, so the caller can keep their current selection.
  static ExpenseType? inferExpense(String text) {
    final cleaned = _normalize(text);
    if (cleaned.isEmpty) return null;

    // We check categories with specific keywords first (excluding 'other')
    for (final type in CategoryMeta.visibleExpenseTypes) {
      if (type == ExpenseType.other) continue;
      final meta = CategoryMeta.expenseMeta[type];
      if (meta == null) continue;

      for (final kw in meta.keywords) {
        if (_matchesKeyword(cleaned, kw)) {
          return type;
        }
      }
    }
    return null;
  }

  /// Attempts to infer the most appropriate [IncomeSource] based on the input text.
  /// Returns `null` if no strong match is found.
  static IncomeSource? inferIncome(String text) {
    final cleaned = _normalize(text);
    if (cleaned.isEmpty) return null;

    for (final source in CategoryMeta.visibleIncomeSources) {
      if (source == IncomeSource.other) continue;
      final meta = CategoryMeta.incomeMeta[source];
      if (meta == null) continue;

      for (final kw in meta.keywords) {
        if (_matchesKeyword(cleaned, kw)) {
          return source;
        }
      }
    }
    return null;
  }

  static String _normalize(String input) {
    return input.toLowerCase().trim();
  }

  static bool _matchesKeyword(String text, String keyword) {
    final kw = keyword.toLowerCase().trim();
    if (kw.isEmpty) return false;

    // Multi-word keyword check (e.g. "mobile bill", "house rent", "odd job")
    if (kw.contains(' ')) {
      return text.contains(kw);
    }

    // Single-word check: either exact match, word boundary, or word starting with keyword
    // e.g. "meds" in "bought meds" or "cigarette" in "cigarettes"
    final words = text.split(RegExp(r'[\s,._\-/]+'));
    for (final word in words) {
      if (word == kw) return true;
      // Plural or slight variation matching (min length 4)
      if (kw.length >= 4 && (word.startsWith(kw) || kw.startsWith(word))) {
        return true;
      }
    }
    return false;
  }
}
