import 'package:bavi/models/thread.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ProfileMetric { curiosity, depth, precision, vocabulary }

enum StatPeriod { daily, weekly, monthly, yearly }

class DailyMetricPoint {
  final DateTime date;
  final double value;
  final String label;

  const DailyMetricPoint({
    required this.date,
    required this.value,
    required this.label,
  });
}

class ProfileStats {
  final int threadCount;
  final int messageCount;
  final int queryCount;
  final int userLevel;
  final double levelProgress;
  final String levelLabel;
  final Map<StatPeriod, Map<ProfileMetric, List<DailyMetricPoint>>> periodData;
  final Map<StatPeriod, Map<ProfileMetric, double>> periodAggregates;

  const ProfileStats({
    required this.threadCount,
    required this.messageCount,
    required this.queryCount,
    required this.userLevel,
    required this.levelProgress,
    required this.levelLabel,
    required this.periodData,
    required this.periodAggregates,
  });

  Map<String, dynamic> toFirestore() => {
        'threadCount': threadCount,
        'messageCount': messageCount,
        'queryCount': queryCount,
        'userLevel': userLevel,
        'levelProgress': levelProgress,
        'levelLabel': levelLabel,
        'curiosityScore':
            periodAggregates[StatPeriod.weekly]?[ProfileMetric.curiosity] ?? 0,
        'depthScore':
            periodAggregates[StatPeriod.weekly]?[ProfileMetric.depth] ?? 0,
        'precisionScore':
            periodAggregates[StatPeriod.weekly]?[ProfileMetric.precision] ?? 0,
        'vocabularyScore':
            periodAggregates[StatPeriod.weekly]?[ProfileMetric.vocabulary] ?? 0,
        'statsUpdatedAt': FieldValue.serverTimestamp(),
      };
}

class ProfileStatsService {
  static const _interrogativeWords = {
    'how', 'what', 'why', 'when', 'where', 'who', 'which', 'whose', 'whom',
  };

  static const _stopwords = {
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'should',
    'could', 'may', 'might', 'must', 'shall', 'can', 'i', 'you', 'he',
    'she', 'it', 'we', 'they', 'me', 'him', 'her', 'us', 'them', 'my',
    'your', 'his', 'its', 'our', 'their', 'this', 'that', 'these', 'those',
    'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'from', 'up',
    'about', 'into', 'through', 'during', 'before', 'after', 'and', 'but',
    'or', 'nor', 'so', 'yet', 'both', 'either', 'each', 'few', 'more',
    'most', 'other', 'some', 'such', 'than', 'too', 'very', 'just', 'as',
    'if', 'not', 'no', 'all', 'any', 'every', 'own', 'same', 'then',
    'only', 'also', 'there', 'here', 'when', 'where', 'how', 'what',
    'which', 'who', 'whom', 'why', 'because', 'while', 'although',
  };

  static const _levelThresholds = [0, 5, 15, 30, 50, 75, 110, 150, 200, 260, 330];
  static const _levelLabels = [
    'Beginner', 'Beginner', 'Novice', 'Novice', 'Intermediate',
    'Intermediate', 'Advanced', 'Advanced', 'Expert', 'Expert', 'Master',
  ];

  static const _hourLabels = [
    '12a', '2a', '4a', '6a', '8a', '10a',
    '12p', '2p', '4p', '6p', '8p', '10p',
  ];

  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static Future<ProfileStats?> fetchAndComputeStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final email = prefs.getString('email') ?? '';

      if (!isLoggedIn || email.isEmpty) return null;

      final db = FirebaseFirestore.instance;
      final userQuery = await db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return null;

      final userDocId = userQuery.docs.first.id;

      final threadQuery = await db
          .collection('threads')
          .where('userId', isEqualTo: userDocId)
          .orderBy('updatedAt', descending: true)
          .get();

      final sessions = threadQuery.docs.map((doc) {
        return ThreadSessionData.fromJson(doc.data());
      }).toList();

      final stats = computeFromSessions(sessions);

      await db.collection('users').doc(userDocId).set(
            stats.toFirestore(),
            SetOptions(merge: true),
          );

      return stats;
    } catch (e) {
      debugPrint('Error fetching/computing profile stats: $e');
      return null;
    }
  }

  static ProfileStats computeFromSessions(List<ThreadSessionData> sessions) {
    final allResults = <ThreadResultData>[];
    for (final session in sessions) {
      if (!session.isIncognito) {
        allResults.addAll(session.results);
      }
    }

    final threadCount = sessions.where((s) => !s.isIncognito).length;
    final messageCount = allResults.length;
    final queryCount = allResults.where((r) => r.searchQuery.isNotEmpty).length;

    final level = _computeLevel(messageCount);
    final progress = _computeLevelProgress(messageCount, level);
    final label = _levelLabels[level];

    final periodData = <StatPeriod, Map<ProfileMetric, List<DailyMetricPoint>>>{};
    final periodAggregates = <StatPeriod, Map<ProfileMetric, double>>{};

    for (final period in StatPeriod.values) {
      final data = _computePeriodData(allResults, period);
      periodData[period] = data;

      final agg = <ProfileMetric, double>{};
      for (final metric in ProfileMetric.values) {
        final points = data[metric]!;
        final nonZero = points.where((p) => p.value > 0).toList();
        if (nonZero.isEmpty) {
          agg[metric] = 0;
        } else {
          final sum = nonZero.fold(0.0, (s, p) => s + p.value);
          agg[metric] = sum / nonZero.length;
        }
      }
      periodAggregates[period] = agg;
    }

    return ProfileStats(
      threadCount: threadCount,
      messageCount: messageCount,
      queryCount: queryCount,
      userLevel: level,
      levelProgress: progress,
      levelLabel: label,
      periodData: periodData,
      periodAggregates: periodAggregates,
    );
  }

  static Future<void> updateStatsInBackground() async {
    try {
      await fetchAndComputeStats();
    } catch (e) {
      debugPrint('Background stats update failed: $e');
    }
  }

  static int _computeLevel(int messageCount) {
    for (int i = _levelThresholds.length - 1; i >= 0; i--) {
      if (messageCount >= _levelThresholds[i]) return i;
    }
    return 0;
  }

  static double _computeLevelProgress(int messageCount, int level) {
    if (level >= _levelThresholds.length - 1) return 1.0;
    final current = messageCount - _levelThresholds[level];
    final needed = _levelThresholds[level + 1] - _levelThresholds[level];
    return (current / needed).clamp(0.0, 1.0);
  }

  // ── Period-aware bucketing ──

  static Map<ProfileMetric, List<DailyMetricPoint>> _computePeriodData(
      List<ThreadResultData> allResults, StatPeriod period) {
    switch (period) {
      case StatPeriod.daily:
        return _computeDailyData(allResults);
      case StatPeriod.weekly:
        return _computeWeeklyData(allResults);
      case StatPeriod.monthly:
        return _computeMonthlyData(allResults);
      case StatPeriod.yearly:
        return _computeYearlyData(allResults);
    }
  }

  /// Daily: 12 x 2-hour buckets for today (12a, 2a, 4a, ... 10p)
  static Map<ProfileMetric, List<DailyMetricPoint>> _computeDailyData(
      List<ThreadResultData> allResults) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final buckets = <int, List<ThreadResultData>>{};
    for (int i = 0; i < 12; i++) {
      buckets[i] = [];
    }

    for (final result in allResults) {
      final d = result.createdAt.toDate();
      if (d.year == today.year && d.month == today.month && d.day == today.day) {
        final bucketIndex = (d.hour ~/ 2).clamp(0, 11);
        buckets[bucketIndex]!.add(result);
      }
    }

    return _buildMetricMap(12, (i) {
      final hour = i * 2;
      return (
        date: today.add(Duration(hours: hour)),
        label: _hourLabels[i],
        results: buckets[i]!,
      );
    });
  }

  /// Weekly: 7 day buckets (Mon–Sun) for current week
  static Map<ProfileMetric, List<DailyMetricPoint>> _computeWeeklyData(
      List<ThreadResultData> allResults) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartMidnight = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final days = List.generate(7, (i) => weekStartMidnight.add(Duration(days: i)));
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final buckets = <int, List<ThreadResultData>>{};
    for (int i = 0; i < 7; i++) {
      buckets[i] = [];
    }

    for (final result in allResults) {
      final d = result.createdAt.toDate();
      for (int i = 0; i < 7; i++) {
        if (d.year == days[i].year &&
            d.month == days[i].month &&
            d.day == days[i].day) {
          buckets[i]!.add(result);
          break;
        }
      }
    }

    return _buildMetricMap(7, (i) {
      return (
        date: days[i],
        label: dayLabels[i],
        results: buckets[i]!,
      );
    });
  }

  /// Monthly: 4 week buckets for current month (Wk 1, Wk 2, Wk 3, Wk 4)
  static Map<ProfileMetric, List<DailyMetricPoint>> _computeMonthlyData(
      List<ThreadResultData> allResults) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final buckets = <int, List<ThreadResultData>>{};
    for (int i = 0; i < 4; i++) {
      buckets[i] = [];
    }

    for (final result in allResults) {
      final d = result.createdAt.toDate();
      if (d.year == now.year && d.month == now.month) {
        final weekIndex = ((d.day - 1) ~/ 7).clamp(0, 3);
        buckets[weekIndex]!.add(result);
      }
    }

    return _buildMetricMap(4, (i) {
      return (
        date: monthStart.add(Duration(days: i * 7)),
        label: 'Wk ${i + 1}',
        results: buckets[i]!,
      );
    });
  }

  /// Yearly: 12 month buckets for current year (Jan–Dec)
  static Map<ProfileMetric, List<DailyMetricPoint>> _computeYearlyData(
      List<ThreadResultData> allResults) {
    final now = DateTime.now();

    final buckets = <int, List<ThreadResultData>>{};
    for (int i = 0; i < 12; i++) {
      buckets[i] = [];
    }

    for (final result in allResults) {
      final d = result.createdAt.toDate();
      if (d.year == now.year) {
        buckets[d.month - 1]!.add(result);
      }
    }

    return _buildMetricMap(12, (i) {
      return (
        date: DateTime(now.year, i + 1, 1),
        label: _monthLabels[i],
        results: buckets[i]!,
      );
    });
  }

  /// Helper to build metric map from indexed buckets
  static Map<ProfileMetric, List<DailyMetricPoint>> _buildMetricMap(
    int count,
    ({DateTime date, String label, List<ThreadResultData> results}) Function(int i) getBucket,
  ) {
    final data = <ProfileMetric, List<DailyMetricPoint>>{};
    for (final metric in ProfileMetric.values) {
      final points = <DailyMetricPoint>[];
      for (int i = 0; i < count; i++) {
        final bucket = getBucket(i);
        final value = _computeMetricForBucket(metric, bucket.results);
        points.add(DailyMetricPoint(
          date: bucket.date,
          value: value,
          label: bucket.label,
        ));
      }
      data[metric] = points;
    }
    return data;
  }

  static double _computeMetricForBucket(
      ProfileMetric metric, List<ThreadResultData> results) {
    if (results.isEmpty) return 0;

    switch (metric) {
      case ProfileMetric.curiosity:
        return _curiosityForBucket(results);
      case ProfileMetric.depth:
        return _depthForBucket(results);
      case ProfileMetric.precision:
        return _precisionForBucket(results);
      case ProfileMetric.vocabulary:
        return _vocabularyForBucket(results);
    }
  }

  static double _curiosityForBucket(List<ThreadResultData> results) {
    double total = 0;
    for (final r in results) {
      final query = r.userQuery.trim().toLowerCase();
      if (query.endsWith('?')) {
        total += 100;
      } else {
        final firstWord = query.split(RegExp(r'\s+')).firstOrNull ?? '';
        if (_interrogativeWords.contains(firstWord)) {
          total += 80;
        }
      }
    }
    return total / results.length;
  }

  static double _depthForBucket(List<ThreadResultData> results) {
    double totalWords = 0;
    for (final r in results) {
      final words = r.userQuery.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      totalWords += words.length;
    }
    return totalWords / results.length;
  }

  static double _precisionForBucket(List<ThreadResultData> results) {
    final technicalTerms = <String>{};
    for (final r in results) {
      final tokens = r.userQuery.trim().toLowerCase().split(RegExp(r'\s+'));
      for (final token in tokens) {
        final cleaned = token.replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (cleaned.length >= 3 && !_stopwords.contains(cleaned)) {
          technicalTerms.add(cleaned);
        }
      }
    }
    return technicalTerms.length.toDouble();
  }

  static double _vocabularyForBucket(List<ThreadResultData> results) {
    final allWords = <String>[];
    final uniqueWords = <String>{};
    for (final r in results) {
      final tokens = r.userQuery.trim().toLowerCase().split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty);
      for (final token in tokens) {
        allWords.add(token);
        uniqueWords.add(token);
      }
    }
    if (allWords.isEmpty) return 0;
    return (uniqueWords.length / allWords.length) * 100;
  }
}
