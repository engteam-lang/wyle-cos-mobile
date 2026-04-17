import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../navigation/app_router.dart';

class MainScreen extends StatelessWidget {
  final Widget child;

  const MainScreen({super.key, required this.child});

  static final List<_TabItem> _tabs = [
    _TabItem(icon: '⊙', label: 'Home',        route: AppRoutes.home),
    _TabItem(icon: '✦', label: 'Automations', route: AppRoutes.obligations),
    _TabItem(icon: 'orb', label: '',           route: AppRoutes.buddy),
    _TabItem(icon: '▦', label: 'Insights',    route: AppRoutes.insights),
    _TabItem(icon: '◈', label: 'Profile',     route: '/main/connect'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _currentIndex(context);

    // Hide tab bar on Buddy screen — it shows its own immersive header + back btn
    final showTabBar = activeIndex != 2;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: child,
      bottomNavigationBar: showTabBar
          ? _WyleTabBar(
              activeIndex: activeIndex,
              onTab: (index) => context.go(_tabs[index].route),
            )
          : null,
    );
  }
}

class _TabItem {
  final String icon;
  final String label;
  final String route;
  const _TabItem({required this.icon, required this.label, required this.route});
}

class _WyleTabBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTab;

  const _WyleTabBar({required this.activeIndex, required this.onTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: AppColors.borderDark, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _buildTab(0, '⊙', 'Home'),
            _buildTab(1, '✦', 'Automations'),
            _buildOrbTab(),
            _buildTab(3, '▦', 'Insights'),
            _buildTab(4, '◈', 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String icon, String label) {
    final isActive = activeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTab(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon,
              style: TextStyle(
                fontSize: 20,
                color: isActive ? AppColors.verdigris : AppColors.textTerDark,
              ),
            ),
            const SizedBox(height: 3),
            Text(label,
              style: TextStyle(
                fontSize: 10,
                color:    isActive ? AppColors.verdigris : AppColors.textTerDark,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 3),
              Container(width: 4, height: 4, decoration: BoxDecoration(
                color: AppColors.verdigris, borderRadius: BorderRadius.circular(2),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrbTab() {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTab(2),
        child: Align(
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: const Offset(0, -10),
            child: const _HologramOrb(),
          ),
        ),
      ),
    );
  }
}

class _HologramOrb extends StatefulWidget {
  const _HologramOrb();

  @override
  State<_HologramOrb> createState() => _HologramOrbState();
}

class _HologramOrbState extends State<_HologramOrb>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _tiltCtrl;
  late Animation<double>    _pulse;
  late Animation<double>    _tilt;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _tiltCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _tilt  = Tween<double>(begin: -0.157, end: 0.157).animate(
      CurvedAnimation(parent: _tiltCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _tiltCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _tiltCtrl]),
      builder: (_, __) {
        return Transform.scale(
          scale: _pulse.value,
          child: Transform.rotate(
            angle: _tilt.value,
            child: Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: AppColors.hologramGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.verdigris.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [1, 1, 3, 6, 3, 1, 1].map((h) => Container(
                    width:  2.5,
                    height: (h * 3).toDouble(),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
