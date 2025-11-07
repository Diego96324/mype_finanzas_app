import 'package:flutter/material.dart';
import '../../../../core/theme/components/analytics_design_system.dart';
import 'reports_tab_view.dart';
import '../../accounts/views/accounts_view.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AnalyticsDesignSystem.backgroundPrimary,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Informes',
              style: AnalyticsDesignSystem.h3.copyWith(fontSize: 20),
            ),
            const SizedBox(height: AnalyticsDesignSystem.spacing8),
            Center(
              child: Container(
                height: 40,
                width: 250,
                decoration: BoxDecoration(
                  color: AnalyticsDesignSystem.backgroundPrimary,
                  borderRadius: BorderRadius.circular(AnalyticsDesignSystem.radiusSmall),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AnalyticsDesignSystem.primary,
                    borderRadius: BorderRadius.circular(AnalyticsDesignSystem.radiusSmall),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AnalyticsDesignSystem.textPrimary,
                  unselectedLabelColor: AnalyticsDesignSystem.textSecondary,
                  labelStyle: AnalyticsDesignSystem.buttonPrimary.copyWith(fontSize: 13),
                  tabs: const [
                    Tab(text: 'Informes'),
                    Tab(text: 'Cuentas'),
                  ],
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: AnalyticsDesignSystem.backgroundSecondary,
        elevation: 0,
        toolbarHeight: 100,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: TabBarView(
          controller: _tabController,
          children: const [
            ReportsTab(),
            AccountsTab(),
          ],
        ),
      ),
    );
  }
}

