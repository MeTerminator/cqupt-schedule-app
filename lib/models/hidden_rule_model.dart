class HiddenRule {
  final String id;
  final String type; // 'all' (隐藏全部该课程), 'time_slot' (隐藏此时间段的全部该课程), 'single' (隐藏此节课程)
  final String courseName;
  final int? day; // 星期几 (1-7)
  final List<int>? periods; // 节数 (如 [3, 4])
  final String? instanceId; // 针对单节课程的唯一 ID
  final int? week; // 针对单节课程的周次 (用于显示)
  final String displayText; // 显示名称

  HiddenRule({
    required this.id,
    required this.type,
    required this.courseName,
    this.day,
    this.periods,
    this.instanceId,
    this.week,
    required this.displayText,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'courseName': courseName,
        'day': day,
        'periods': periods,
        'instanceId': instanceId,
        'week': week,
        'displayText': displayText,
      };

  factory HiddenRule.fromJson(Map<String, dynamic> json) {
    return HiddenRule(
      id: json['id'] ?? '',
      type: json['type'] ?? 'all',
      courseName: json['courseName'] ?? '',
      day: json['day'] as int?,
      periods: json['periods'] != null ? List<int>.from(json['periods']) : null,
      instanceId: json['instanceId'] as String?,
      week: json['week'] as int?,
      displayText: json['displayText'] ?? '',
    );
  }
}
