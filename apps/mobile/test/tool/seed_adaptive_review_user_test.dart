import 'package:flutter_test/flutter_test.dart';

import '../../tool/seed_adaptive_review_user.dart';

void main() {
  group('Seed config and CLI validation', () {
    final baseArgs = [
      '--scenario',
      'too-aggressive',
      '--review',
      'pending',
      '--email',
      'adaptive.runner@example.test',
      '--password',
      'AdaptiveTest123!',
      '--anon-key',
      'anon-key',
      '--service-role-key',
      'service-role-key',
    ];

    SeedConfig parseWithUrl(String supabaseUrl) {
      return SeedConfig.fromCli(
        CliArgs.parse([...baseArgs, '--supabase-url', supabaseUrl]),
      );
    }

    test('rejects non-local Supabase URLs', () {
      expect(
        () => parseWithUrl('https://project.supabase.co'),
        throwsA(isA<UsageException>()),
      );
    });

    test('accepts local Supabase URLs', () {
      final config = parseWithUrl('http://127.0.0.1:54321');
      expect(config.supabaseUrl.host, '127.0.0.1');
      expect(config.supabaseUrl.port, 54321);
    });

    test('rejects removed --allow-remote CLI flag', () {
      expect(
        () => CliArgs.parse(['--allow-remote']),
        throwsA(isA<UsageException>()),
      );
    });
  });

  group('seeded race-date behavior', () {
    test('uses next year when seed time is on Oct 18', () {
      final raceDate = seededRaceDate(DateTime(2026, 10, 18, 12));
      expect(raceDate.year, 2027);
      expect(raceDate.month, 10);
      expect(raceDate.day, 18);
    });

    test('uses current-year Oct 18 when seed time is before Oct 18', () {
      final seedTime = DateTime(2026, 10, 17, 12);
      final raceDate = seededRaceDate(seedTime);
      expect(raceDate, DateTime(2026, 10, 18));
      expect(raceDate.isAfter(seedTime), isTrue);
    });

    test('uses next-year Oct 18 when seed time is after Oct 18', () {
      final seedTime = DateTime(2026, 10, 19, 12);
      final raceDate = seededRaceDate(seedTime);
      expect(raceDate.year, 2027);
      expect(raceDate, DateTime(2027, 10, 18));
      expect(raceDate.isAfter(seedTime), isTrue);
    });
  });
}
