import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../features/bluetooth/presentation/bloc/bluetooth_state.dart';

/// Shell widget providing bottom navigation for the main app.
/// Styled to match FlutterFlow NavigationBarWidget design.
class AppShell extends StatelessWidget {
  final Widget child;

  // FF Colors
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _secondaryText = Color(0xFF57636C);
  static const Color _secondaryBackground = Color(0xFFFFFFFF);

  const AppShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const _BottomNavBar(),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  // FF Colors
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _secondaryText = Color(0xFF57636C);
  static const Color _secondaryBackground = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _calculateSelectedIndex(location);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      child: Container(
        width: double.infinity,
        height: 69.0,
        decoration: BoxDecoration(
          color: _secondaryBackground,
          boxShadow: const [
            BoxShadow(
              blurRadius: 8.0,
              color: Color(0x33000000),
              offset: Offset(0.0, -2.0),
            ),
          ],
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 17.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NavIcon(
                icon: Icons.home_rounded,
                isSelected: currentIndex == 0,
                onTap: () => _onItemTapped(context, 0),
              ),
              _BluetoothNavIcon(
                isSelected: currentIndex == 1,
                onTap: () => _onItemTapped(context, 1),
              ),
              _NavIcon(
                icon: Icons.person_rounded,
                isSelected: currentIndex == 2,
                onTap: () => _onItemTapped(context, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(String location) {
    if (location.startsWith('/bluetooth') ||
        location.startsWith('/deviceManagement') ||
        location.startsWith('/connectionInitiation')) {
      return 1;
    } else if (location.startsWith('/profile')) {
      return 2;
    }
    return 0; // Items (home)
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/bluetooth');
        break;
      case 2:
        context.go('/profile');
        break;
    }
  }
}

/// Simple nav icon without label (FF style)
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  // FF Colors
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _secondaryText = Color(0xFF57636C);

  const _NavIcon({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Icon(
        icon,
        color: isSelected ? _primary : _secondaryText,
        size: 35.0,
      ),
    );
  }
}

/// Bluetooth nav icon with connection status (FF style)
class _BluetoothNavIcon extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  // FF Colors
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _secondaryText = Color(0xFF57636C);

  const _BluetoothNavIcon({
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, state) {
        return InkWell(
          splashColor: Colors.transparent,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Icon(
            Icons.bluetooth_connected,
            color: isSelected ? _primary : _secondaryText,
            size: 35.0,
          ),
        );
      },
    );
  }
}
