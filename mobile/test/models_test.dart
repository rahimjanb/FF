import 'package:fitness_formulasi/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

void main() {
  test('dashboard parses enums, club dates and nested objects', () {
    final d = ClientDashboard.fromJson(FakeBackend.dashboard());
    final m = d.currentMembership!;
    expect(m.effectiveStatus, MembershipEffectiveStatus.active);
    expect(m.startDate, DateTime(2026, 10, 5)); // calendar date, no time zone shift
    expect(m.endDate, DateTime(2026, 11, 3));
    expect(m.totalDays, 30);
    expect(d.visits.total, 17);
    expect(d.unreadNotifications, 2);
    expect(d.trainer, isNull);
  });

  test('expired membership is parsed as expired', () {
    final m = Membership.fromJson(FakeBackend.membership(status: 'Expired', daysLeft: 0));
    expect(m.effectiveStatus, MembershipEffectiveStatus.expired);
  });

  test('unknown notification type does not crash', () {
    final n = AppNotification.fromJson({
      'id': '1',
      'type': 'SomethingNew',
      'relatedEntityId': null,
      'payload': null,
      'isRead': false,
      'createdAt': '2026-10-01T00:00:00Z',
    });
    expect(n.type, NotificationType.unknown);
  });

  test('profile update serializes birth date as yyyy-MM-dd', () {
    final json = ProfileUpdate(firstName: 'A', lastName: 'B', birthDate: DateTime(1995, 3, 7)).toJson();
    expect(json['birthDate'], '1995-03-07');
  });
}
