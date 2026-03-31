import '../models/month_summary.dart';
import '../repositories/wallet_repository.dart';

class MonthRolloverService {
  final WalletRepository _repo = WalletRepository();

  Future<void> checkAndRollover() async {
    final now = DateTime.now();
    final currentMonthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    var currentSummary = _repo.getMonthSummary(currentMonthId);
    if (currentSummary == null) {
       // Pull previous month id computationally accurately
       int prevYear = now.year;
       int prevMonth = now.month - 1;
       if (prevMonth == 0) {
          prevMonth = 12;
          prevYear -= 1;
       }
       final prevMonthId = '${prevYear}-${prevMonth.toString().padLeft(2, '0')}';
       
       final prevSummary = _repo.getMonthSummary(prevMonthId);
       
       double newOpeningBalance = 0.0;
       
       if (prevSummary != null) {
           newOpeningBalance = prevSummary.closingBalance;
       } 
       
       currentSummary = MonthSummary(
           id: currentMonthId,
           openingBalance: newOpeningBalance,
           totalIncome: 0.0,
           totalExpense: 0.0,
           closingBalance: newOpeningBalance,
           isClosed: false,
       );
       
       await _repo.saveMonthSummary(currentSummary);
    }
  }
}
