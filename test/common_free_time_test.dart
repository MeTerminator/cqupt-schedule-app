import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cqupt_schedule_app/view_models/schedule_view_model.dart';
import 'package:cqupt_schedule_app/models/schedule_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Common Free Time calculation mathematical correctness test', () {
    final viewModel = ScheduleViewModel();

    // Set showCommonFreeTime to true
    viewModel.showCommonFreeTime = true;
    viewModel.checkedUserIds = ['user1', 'user2'];

    // Setup loadedSchedules
    viewModel.loadedSchedules['user1'] = ScheduleResponse(
      studentId: 'user1',
      studentName: 'User One',
      academicYear: '2025-2026',
      semester: '2',
      week1Monday: '2026-03-02',
      instances: [
        CourseInstance(
          id: 'course1',
          course: 'Math',
          week: 1,
          day: 1, // Monday
          periods: [1, 2], // Mon 1-2
          startTime: '08:00',
          endTime: '09:40',
          location: 'Building A',
          type: 'Regular',
        ),
      ],
    );

    viewModel.loadedSchedules['user2'] = ScheduleResponse(
      studentId: 'user2',
      studentName: 'User Two',
      academicYear: '2025-2026',
      semester: '2',
      week1Monday: '2026-03-02',
      instances: [
        CourseInstance(
          id: 'course2',
          course: 'English',
          week: 1,
          day: 1, // Monday
          periods: [2, 3], // Mon 2-3
          startTime: '08:55',
          endTime: '11:00',
          location: 'Building B',
          type: 'Regular',
        ),
      ],
    );

    // Call calculation
    final freePeriods = viewModel.getCommonFreePeriods(1);

    // Verify Mon 1, 2, 3 are NOT in free periods because Mon 1,2 are busy for user1 and Mon 2,3 are busy for user2
    expect(freePeriods.contains('1_1'), isFalse);
    expect(freePeriods.contains('1_2'), isFalse);
    expect(freePeriods.contains('1_3'), isFalse);

    // Verify Mon 4, 5 and Tuesday 1, 2 are in free periods
    expect(freePeriods.contains('1_4'), isTrue);
    expect(freePeriods.contains('2_1'), isTrue);
  });
}
