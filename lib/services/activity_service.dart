import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kDefaultDailyGoal = 10;

/// How many days of activity to keep in the persisted log. Only the most
/// recent 7 are ever displayed (see [lastNDays]), but a little slack makes
/// the "last 7 calendar days" window correct without extra bookkeeping.
const int _kWeeklyLogRetentionDays = 14;

/// Tracks "did the user do *something* today" across every practice mode in
/// the app -- quizzes (via [recordActivity] called alongside
/// SettingsService.recordAnswer) and spaced-repetition reviews/flashcards
/// (via [recordActivity] called alongside ProgressService.rate/rate).
///
/// This is deliberately a separate, single-purpose service rather than more
/// fields bolted onto SettingsService or ProgressService -- streak/goal
/// tracking is its own concern with its own persisted shape, matching how
/// the rest of the app already splits by concern (audio, theme, SRS,
/// settings).
///
/// Streak and "today's count" are computed as *derived* getters rather than
/// mutated on load -- see [currentStreak] and [todayCount] -- so simply
/// opening the app on a new day never writes anything or silently breaks a
/// streak; only a real [recordActivity] call ever changes persisted state.
class ActivityService extends ChangeNotifier {
  static const _kLastActiveDate = 'activity_last_active_date';
  static const _kTodayCount = 'activity_today_count';
  static const _kStreak = 'activity_streak';
  static const _kLongestStreak = 'activity_longest_streak';
  static const _kDailyGoal = 'activity_daily_goal';
  static const _kWeeklyLog = 'activity_weekly_log_v1';

  String? _lastActiveDate; // 'YYYY-MM-DD', the last day with any activity
  int _rawTodayCount = 0; // activity count as of _lastActiveDate
  int _rawStreak = 0; // consecutive-day count as of _lastActiveDate
  int _longestStreak = 0;
  int _dailyGoal = kDefaultDailyGoal;
  Map<String, int> _weeklyLog = {}; // 'YYYY-MM-DD' -> activity count

  int get dailyGoal => _dailyGoal;
  int get longestStreak => _longestStreak;

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _todayKey() => _dateKey(DateTime.now());

  static String _yesterdayKey() =>
      _dateKey(DateTime.now().subtract(const Duration(days: 1)));

  /// Today's activity count. Reads the raw persisted counter only if it was
  /// actually recorded *today*; otherwise a day has clearly turned over
  /// since the last activity, so today's count is genuinely zero.
  int get todayCount => _lastActiveDate == _todayKey() ? _rawTodayCount : 0;

  /// The current streak, still counting today if today has activity, or
  /// still counting as "alive" if yesterday did (the usual one-day grace
  /// before a streak is considered broken). Once more than one full day has
  /// passed with no activity, this reads as 0 without needing a write.
  int get currentStreak {
    if (_lastActiveDate == null) return 0;
    if (_lastActiveDate == _todayKey() || _lastActiveDate == _yesterdayKey()) {
      return _rawStreak;
    }
    return 0;
  }

  double get goalProgress {
    if (_dailyGoal <= 0) return 0.0;
    // num.clamp() returns num, not double -- .toDouble() avoids a type
    // error here, matching the same workaround ThemedProgressBar already
    // uses internally for the same reason.
    return (todayCount / _dailyGoal).clamp(0.0, 1.0).toDouble();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastActiveDate = prefs.getString(_kLastActiveDate);
      _rawTodayCount = prefs.getInt(_kTodayCount) ?? 0;
      _rawStreak = prefs.getInt(_kStreak) ?? 0;
      _longestStreak = prefs.getInt(_kLongestStreak) ?? 0;
      _dailyGoal = prefs.getInt(_kDailyGoal) ?? kDefaultDailyGoal;
      final rawLog = prefs.getString(_kWeeklyLog);
      if (rawLog != null && rawLog.isNotEmpty) {
        final decoded = jsonDecode(rawLog) as Map<String, dynamic>;
        _weeklyLog = decoded.map((k, v) => MapEntry(k, v as int));
      }
    } catch (e) {
      debugPrint('ActivityService.load failed, using defaults: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastActiveDate != null) {
        await prefs.setString(_kLastActiveDate, _lastActiveDate!);
      }
      await prefs.setInt(_kTodayCount, _rawTodayCount);
      await prefs.setInt(_kStreak, _rawStreak);
      await prefs.setInt(_kLongestStreak, _longestStreak);
      await prefs.setInt(_kDailyGoal, _dailyGoal);
      await prefs.setString(_kWeeklyLog, jsonEncode(_weeklyLog));
    } catch (e) {
      debugPrint('ActivityService.save failed (kept in memory only): $e');
    }
  }

  /// Call once per completed study action -- one quiz answer, one flashcard
  /// swipe, one review rating. Cheap and idempotent-safe to call often;
  /// there's no dedupe needed since every call really is one more thing the
  /// user did.
  Future<void> recordActivity() async {
    final today = _todayKey();
    if (_lastActiveDate == today) {
      _rawTodayCount += 1;
    } else {
      _rawStreak = (_lastActiveDate == _yesterdayKey()) ? _rawStreak + 1 : 1;
      _rawTodayCount = 1;
      _lastActiveDate = today;
    }
    if (_rawStreak > _longestStreak) _longestStreak = _rawStreak;
    _weeklyLog[today] = (_weeklyLog[today] ?? 0) + 1;
    _trimWeeklyLog();
    notifyListeners();
    await _save();
  }

  Future<void> setDailyGoal(int goal) async {
    _dailyGoal = goal.clamp(1, 999).toInt();
    notifyListeners();
    await _save();
  }

  void _trimWeeklyLog() {
    if (_weeklyLog.length <= _kWeeklyLogRetentionDays) return;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: _kWeeklyLogRetentionDays));
    _weeklyLog.removeWhere((key, _) {
      final d = DateTime.tryParse(key);
      return d == null || d.isBefore(cutoff);
    });
  }

  /// Activity counts for the last [n] calendar days, oldest first, ending
  /// today. Days with no recorded activity read as 0 -- there is no
  /// separate "no data" state to fake, an empty day really did have zero
  /// study actions.
  List<int> lastNDays(int n) {
    final now = DateTime.now();
    return List<int>.generate(n, (i) {
      final day = now.subtract(Duration(days: n - 1 - i));
      return _weeklyLog[_dateKey(day)] ?? 0;
    });
  }
}
