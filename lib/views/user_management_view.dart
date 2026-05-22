import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../view_models/schedule_view_model.dart';

class UserManagementView extends StatefulWidget {
  final ScheduleViewModel viewModel;

  const UserManagementView({super.key, required this.viewModel});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  final TextEditingController _idController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const Color schoolGreen = Color.fromRGBO(0, 122, 89, 1);

  bool get isValidId =>
      _idController.text.length == 10 &&
      _idController.text.replaceAll(RegExp(r'[0-9]'), '').isEmpty;

  @override
  void initState() {
    super.initState();
    _idController.addListener(() {
      setState(() {});
    });
    // 打开页面时，刷新/加载所有用户数据以确保显示名字正确
    widget.viewModel.loadAllProfilesData();
  }

  @override
  void dispose() {
    _idController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleAddUser() async {
    final id = _idController.text.trim();
    if (!isValidId) return;

    _focusNode.unfocus();
    final success = await widget.viewModel.addUserProfile(id);
    if (success) {
      _idController.clear();
    }
  }

  void _confirmDelete(String studentId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除用户档案'),
        content: Text('确定要删除用户 $name ($studentId) 吗？\n该操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.viewModel.deleteUserProfile(studentId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBgColor = isDark ? Colors.grey[850] : Colors.grey[200];

    return Consumer<ScheduleViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              '多账号管理',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 添加账号卡片
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '添加学号绑定',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: inputBgColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TextField(
                                      controller: _idController,
                                      focusNode: _focusNode,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      decoration: InputDecoration(
                                        hintText: '请输入10位数字学号',
                                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                                        prefixIcon: const Icon(Icons.badge_outlined, color: schoolGreen),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                      ),
                                      onSubmitted: (_) => _handleAddUser(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: isValidId ? _handleAddUser : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isValidId ? schoolGreen : Colors.grey[400],
                                      foregroundColor: Colors.white,
                                      elevation: isValidId ? 2 : 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_rounded, size: 20),
                                        SizedBox(width: 4),
                                        Text('绑定'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2. 共同空闲时间配置栏
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: schoolGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.people_outline_rounded, color: schoolGreen, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '共同空闲时间标记',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '勾选列表中的用户，在课表上显示交集空闲时间',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: viewModel.showCommonFreeTime,
                              activeColor: schoolGreen,
                              onChanged: (val) {
                                viewModel.toggleCommonFreeTime(val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        '用户档案列表 (${viewModel.userProfiles.length})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 3. 用户列表
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: viewModel.userProfiles.length,
                        itemBuilder: (context, index) {
                          final id = viewModel.userProfiles[index];
                          final schedule = viewModel.loadedSchedules[id];
                          final name = schedule?.studentName ?? '加载中...';
                          final isActive = (id == viewModel.currentId);
                          final isChecked = viewModel.checkedUserIds.contains(id);

                          // 根据姓名生成好看的头像背景色
                          final Color avatarBgColor = Color.lerp(
                            schoolGreen,
                            Colors.blueAccent,
                            (id.hashCode % 10) / 10.0,
                          )!.withOpacity(0.8);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive
                                    ? schoolGreen
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  if (!isActive) {
                                    HapticFeedback.mediumImpact();
                                    viewModel.switchProfile(id);
                                    Navigator.pop(context);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      // 共同空闲时间勾选框
                                      Checkbox(
                                        value: isChecked,
                                        activeColor: schoolGreen,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        onChanged: (val) {
                                          if (val != null) {
                                            viewModel.toggleCheckedUser(id, val);
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      // 头像
                                      CircleAvatar(
                                        backgroundColor: avatarBgColor,
                                        child: Text(
                                          name.isNotEmpty ? name.substring(0, 1) : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // 信息
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                if (isActive) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: schoolGreen
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      '当前使用',
                                                      style: TextStyle(
                                                        color: schoolGreen,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '学号: $id',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 操作按钮：删除
                                      if (!isActive)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.redAccent,
                                            size: 22,
                                          ),
                                          onPressed: () =>
                                              _confirmDelete(id, name),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // 全局加载动画遮罩 (添加用户时展示)
                if (viewModel.isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.4),
                    child: const Center(
                      child: Card(
                        shape: CircleBorder(),
                        elevation: 4,
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(
                            color: schoolGreen,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
