/// 지금 모임에서 나가거나 모임을 지우는 일 (실제 앱에서 모임 화면이 넣어줘요).
class GroupExit {
  const GroupExit({required this.leave, required this.delete});

  /// 모임 나가기 (회원). 총무면 막혀요.
  final Future<void> Function() leave;

  /// 모임 지우기 (총무·회장). 되돌릴 수 없어요.
  final Future<void> Function() delete;
}
