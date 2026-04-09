import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'view_models/schedule_view_model.dart';
import 'views/login_view.dart';
import 'widgets/header_view.dart';
import 'widgets/schedule_grid.dart';
import 'widgets/course_detail_view.dart';
import 'widgets/user_detail_view.dart';
import 'widgets/toast_view.dart';
import 'models/theme_model.dart';
import 'package:path_provider/path_provider.dart';
import 'services/widget_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ScheduleViewModel _viewModel = ScheduleViewModel();
  String? _savedId;
  bool _isLoggedIn = false;
  bool _isLoading = true;

  static const Color schoolGreen = Color.fromRGBO(0, 122, 89, 1);

  @override
  void initState() {
    super.initState();
    _loadSavedId();
  }

  Future<void> _loadSavedId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('saved_id');
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    setState(() {
      _savedId = savedId;
      _isLoggedIn = isLoggedIn && savedId != null && savedId.isNotEmpty;
      _isLoading = false;
    });

    if (_isLoggedIn && _savedId != null) {
      _viewModel.startup(_savedId!);
    }
  }

  Future<void> _saveLoginState(String id, bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_id', id);
    await prefs.setBool('is_logged_in', isLoggedIn);
  }

  void _handleLogin(String id) {
    setState(() {
      _isLoggedIn = true;
      _savedId = id;
    });
    _saveLoginState(id, true);
    _viewModel.startup(id);
    // 登录后会生成颜色映射，不需要手动调用
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _savedId = null;
    });
    _saveLoginState('', false);
    _viewModel.currentId = '';
    _viewModel.scheduleData = null;
    _viewModel.clearAllColorMaps(); // 清空课程颜色映射
    WidgetService.clearWidgetData(); // 清空 Widget 和 Watch 数据
    _viewModel.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );

    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: schoolGreen),
          useMaterial3: true,
        ),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '重邮课表',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: schoolGreen,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: schoolGreen,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
        themeMode: ThemeMode.system,
        home: _isLoggedIn
            ? MainHomeView(viewModel: _viewModel, onLogout: _handleLogout)
            : LoginView(onLogin: _handleLogin),
      ),
    );
  }
}

class MainHomeView extends StatefulWidget {
  final ScheduleViewModel viewModel;
  final VoidCallback onLogout;

  const MainHomeView({
    super.key,
    required this.viewModel,
    required this.onLogout,
  });

  @override
  State<MainHomeView> createState() => _MainHomeViewState();
}

class _MainHomeViewState extends State<MainHomeView> {
  late PageController _pageController;

  Future<Decoration?> _buildBackgroundDecoration(
    ScheduleViewModel viewModel,
  ) async {
    final backgroundType = viewModel.backgroundType;
    final backgroundColor = viewModel.backgroundColor;
    final backgroundImagePath = viewModel.backgroundImagePath;

    if (backgroundType == BackgroundType.image && backgroundImagePath != null) {
      if (kIsWeb) {
        // Web 平台：从内存字节加载
        final bytes = viewModel.backgroundImageBytes;
        if (bytes != null) {
          return BoxDecoration(
            image: DecorationImage(
              image: MemoryImage(bytes),
              fit: BoxFit.cover,
            ),
          );
        }
      } else {
        // 原生平台：从文件系统加载
        final appDir = await getApplicationDocumentsDirectory();
        final file = File('${appDir.path}/$backgroundImagePath');

        if (await file.exists()) {
          return BoxDecoration(
            image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
          );
        }
      }
    } else if (backgroundColor != null) {
      return BoxDecoration(color: backgroundColor);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.viewModel.selectedWeek,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showCourseDetail(BuildContext context, course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CourseDetailView(course: course, viewModel: widget.viewModel),
    );
  }

  void _showUserSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserDetailView(
        viewModel: widget.viewModel,
        onLogout: widget.onLogout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleViewModel>(
      builder: (context, viewModel, child) {
        // 1. 处理 PageView 跳转逻辑
        if (_pageController.hasClients &&
            _pageController.page?.round() != viewModel.selectedWeek) {
          Future.microtask(() {
            if (viewModel.shouldAnimateToWeek) {
              _pageController.animateToPage(
                viewModel.selectedWeek,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
              );
              viewModel.shouldAnimateToWeek = false;
            } else {
              _pageController.jumpToPage(viewModel.selectedWeek);
            }
          });
        }

        // 2. 异步获取背景 Decoration
        return FutureBuilder<Decoration?>(
          future: _buildBackgroundDecoration(viewModel),
          builder: (context, snapshot) {
            final decoration = snapshot.data;

            return Stack(
              children: [
                Scaffold(
                  // 如果有背景图片，设置背景为透明以显示 Container 里的图片
                  backgroundColor: decoration != null
                      ? Colors.transparent
                      : null,
                  body: Container(
                    decoration: decoration,
                    child: Column(
                      children: [
                        HeaderView(
                          viewModel: viewModel,
                          onUserTap: () => _showUserSheet(context),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: 21,
                            onPageChanged: (index) {
                              viewModel.selectedWeek = index;
                              viewModel.notifyListeners();
                            },
                            itemBuilder: (context, index) {
                              return ScheduleGrid(
                                viewModel: viewModel,
                                weekToShow: index,
                                onCourseTap: (course) =>
                                    _showCourseDetail(context, course),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 3. Toast 提示层
                if (viewModel.showToast)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedSlide(
                      offset: viewModel.showToast
                          ? Offset.zero
                          : const Offset(0, -1),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: Center(
                        child: ToastView(message: viewModel.toastMessage),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
