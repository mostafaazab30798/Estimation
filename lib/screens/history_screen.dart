import 'package:flutter/material.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MatchRecord> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService.getHistory();
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المباريات'),
        backgroundColor: AppTheme.feltGreenDark,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('مسح السجل'),
                    content: const Text('هل أنت متأكد من مسح جميع المباريات السابقة؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                        child: const Text('مسح', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await HistoryService.clearHistory();
                  _loadHistory();
                }
              },
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.feltGreenDark, AppTheme.feltGreen],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
            : _history.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد مباريات سابقة',
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final record = _history[index];
                      final date = DateTime.tryParse(record.date);
                      final dateStr = date != null
                          ? '${date.year}/${date.month}/${date.day} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
                          : record.date;
                      
                      return Card(
                        color: AppTheme.surfaceCard,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          iconColor: AppTheme.gold,
                          collapsedIconColor: AppTheme.gold,
                          title: Text(
                            'الفائز: ${record.winnerName} 👑',
                            style: const TextStyle(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                          subtitle: Text(
                            '$dateStr • ${record.winnerScore} نقطة',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.black12,
                              child: Column(
                                children: record.players.map((p) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${p.name} ${p.rankTitle.isNotEmpty ? "- ${p.rankTitle}" : ""}', 
                                             style: const TextStyle(color: Colors.white, fontSize: 14)),
                                        Text('${p.score} نقطة', 
                                             style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
