// lib/presentation/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jinu/presentation/screens/settings_page.dart';
import 'package:jinu/presentation/widgets/translate_widget.dart'; // Ensure this path is correct for TranslateScreen
import '../providers/sidebar_provider.dart';
import '../widgets/left_navigation_panel.dart';
import '../widgets/center_content_panel.dart';
import '../widgets/right_settings_panel.dart';
import '../widgets/image_generating.dart'; // Ensure this path is correct for ImageGenerationDrawer

class AiStudioHomePage extends ConsumerStatefulWidget {
  const AiStudioHomePage({super.key});
  @override _AiStudioHomePageConsumerState createState() => _AiStudioHomePageConsumerState();
}

class _AiStudioHomePageConsumerState extends ConsumerState<AiStudioHomePage> with TickerProviderStateMixin {
  late TabController _leftDrawerTabController;
  late TabController _rightDrawerTabController;
  // _ImageGenerationDrawerController seems unused, remove if truly not needed for a TabBar

  @override
  void initState() {
    super.initState();
    _leftDrawerTabController = TabController(length: 1, vsync: this); // History, Web (Categories), Coming Soon
    _rightDrawerTabController = TabController(length: 3, vsync: this); // Chat Params, Image Gen, Translate
  }

  @override
  void dispose() {
    _leftDrawerTabController.dispose();
    _rightDrawerTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSidebarCollapsed = ref.watch(sidebarCollapsedProvider);
    final double sidebarWidth = isSidebarCollapsed ? 70.0 : 260.0; // Adjusted collapsed width for icons
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800; // Breakpoint for drawers (increased a bit)
    final theme = Theme.of(context);

    if (isSmallScreen) {
      // Mobile/Tablet Layout: Use Drawers with Tabs
      return Scaffold(
        appBar: AppBar(
          title: const Text('Jinu Ai'),
          // backgroundColor: theme.colorScheme.surfaceContainerHighest, // Use theme color
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (context) => const SettingsPage())),
            ),
          ],
        ),
        drawer: Drawer( // Left Drawer
          // backgroundColor: theme.colorScheme.surface,
          child: Column(
            children: [
              TabBar(
                controller: _leftDrawerTabController,
                tabs: const [
                  Tab(icon: Icon(Icons.history), text: 'History'), // Simplified text
           //       Tab(icon: Icon(Icons.explore_outlined), text: 'Explore'), // Changed from Web
            //      Tab(icon: Icon(Icons.new_releases_outlined), text: 'Updates'), // Changed from Coming Soon
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _leftDrawerTabController,
                  children: [
                    LeftNavigationPanel(isMobileLayout: true, isCollapsed: false),
  //                  const Center(child: Text('Explore Content (Future)')), // Placeholder
//                    const Center(child: Text('Updates Content (Future)')), // Placeholder
                  ],
                ),
              ),
            ],
          ),
        ),
        endDrawer: Drawer( // Right Drawer (Tools)
          // backgroundColor: theme.colorScheme.surface,
          child: Column(
            children: [
              TabBar(
                controller: _rightDrawerTabController,
                tabs: const [
                  Tab(icon: Icon(Icons.tune_outlined), text: 'Params'), // Simplified
                  Tab(icon: Icon(Icons.image_outlined), text: 'Image Gen'),
                  Tab(icon: Icon(Icons.translate_outlined), text: 'Translate'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _rightDrawerTabController,
                  children: [
                    const RightSettingsPanel(),
                    ImageGenerationDrawer(), // This is a StatefulWidget, ensure content is scrollable if needed
                   TranslateScreen(), // This is a StatefulWidget
                  ],
                ),
              ),
            ],
          ),
        ),
        body: CenterContentPanel(isMobileLayout: isSmallScreen),
      );
    } else {
      // Desktop Layout
      return Scaffold(
        body: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOutCubic,
              width: sidebarWidth,
              color: theme.colorScheme.surfaceContainer, // Use theme color
              child: Column(
                children: [
                  SizedBox(height: 8), // Space for window controls on desktop
                  TabBar(
                    controller: _leftDrawerTabController,
                    isScrollable: isSidebarCollapsed, // Make tabs scrollable if collapsed width is too small
                    indicatorSize: TabBarIndicatorSize.label, // More compact indicator
                    tabs: [
                      _buildDesktopTab(Icons.history, 'History', isSidebarCollapsed),
            //          _buildDesktopTab(Icons.explore_outlined, 'Explore', isSidebarCollapsed),
             //         _buildDesktopTab(Icons.new_releases_outlined, 'Updates', isSidebarCollapsed),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _leftDrawerTabController,
                      children: [
                        LeftNavigationPanel(isMobileLayout: false, isCollapsed: isSidebarCollapsed),
               //         Center(child: Text('Explore Content (Future)')),
                 //       Center(child: Text('Updates Content (Future)')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(flex: 3, child: CenterContentPanel(isMobileLayout: false)),
            const VerticalDivider(width: 1, thickness: 1),
            Container( // Right Panel for Desktop
              width: 360, // Slightly wider for better tool layout
              color: theme.colorScheme.surfaceContainer,
              child: Column(
                children: [
                   SizedBox(height: 8),
                  TabBar(
                    controller: _rightDrawerTabController,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [ // Text only for desktop right panel tabs for cleaner look
                      Tab(text: 'Chat Params'),
                      Tab(text: 'Image Gen'),
                      Tab(text: 'Translate'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _rightDrawerTabController,
                      children: [
                        const RightSettingsPanel(),
                        ImageGenerationDrawer(),
                         TranslateScreen(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDesktopTab(IconData icon, String text, bool isCollapsed) {
    if (isCollapsed) {
      return Tab(icon: Icon(icon));
    }
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18), // Smaller icon
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)), // Slightly smaller text
        ],
      ),
    );
  }
}