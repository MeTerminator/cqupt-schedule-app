import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart';
import '../widgets/header_view.dart';
import '../widgets/schedule_grid.dart';
import '../widgets/course_detail_view.dart';
import '../widgets/user_detail_view.dart';
import 'login_view.dart';

class HomeView extends StatefulWidget {
  final ScheduleViewModel viewModel;
  final VoidCallback? onLogout;

  const HomeView({super.key, required this.viewModel, this.onLogout});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.viewModel,
      child: Consumer<ScheduleViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            body: Column(
              children: [
                HeaderView(
                  viewModel: viewModel,
                  onUserTap: () {
                    _showUserSheet(context, viewModel);
                  },
                ),
                Expanded(
                  child: PageView.builder(
                    itemCount: 23,
                    controller: PageController(
                      initialPage: viewModel.selectedWeek,
                    ),
                    onPageChanged: (index) {
                      viewModel.updateSelectedWeek(index);
                    },
                    itemBuilder: (context, index) {
                      return ScheduleGrid(
                        viewModel: viewModel,
                        weekToShow: index,
                        onCourseTap: (course) {
                          _showCourseDetail(context, course, viewModel);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCourseDetail(
    BuildContext context,
    CourseInstance course,
    ScheduleViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CourseDetailView(course: course, viewModel: viewModel),
    );
  }

  void _showUserSheet(BuildContext context, ScheduleViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserDetailView(
        viewModel: viewModel,
        onLogout: () {
          viewModel.performLogout();
          if (widget.onLogout != null) {
            widget.onLogout!();
          }
          Navigator.pop(context);
        },
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final ScheduleViewModel _viewModel = ScheduleViewModel();
  String? _savedId;
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedId();
  }

  Future<void> _loadSavedId() async {
    await _viewModel.loadCustomCourses();
    final savedId = await _getSavedId();
    setState(() {
      _savedId = savedId;
      _isLoggedIn = savedId != null && savedId.isNotEmpty;
      _isLoading = false;
    });

    if (_isLoggedIn && _savedId != null) {
      _viewModel.startup(_savedId!);
    }
  }

  Future<String?> _getSavedId() async {
    return null;
  }

  Future<void> _saveId(String id) async {}

  void _handleLogin(String id) {
    setState(() {
      _isLoggedIn = true;
      _savedId = id;
    });
    _saveId(id);
    _viewModel.startup(id);
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _savedId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromRGBO(0, 122, 89, 1),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromRGBO(0, 122, 89, 1),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: _isLoggedIn
            ? HomeView(
                viewModel: _viewModel,
                onLogout: _handleLogout,
              )
            : LoginView(onLogin: _handleLogin),
      ),
    );
  }
}
