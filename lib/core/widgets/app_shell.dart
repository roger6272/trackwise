import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../features/bluetooth/presentation/bloc/bluetooth_state.dart';
import '../theme/app_colors.dart';
import '../utils/app_util.dart';

/// Shell widget providing bottom navigation for the main app.
/// Styled to match FlutterFlow NavigationBarWidget design.
class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({
    super.key,
    required this.child,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Tracks whether we're waiting for an auto-reconnect to succeed.
  bool _awaitingReconnect = false;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Detect unexpected disconnect (manual goes through disconnecting first)
        BlocListener<BluetoothBloc, BluetoothState>(
          listenWhen: (prev, curr) =>
              prev.status == BluetoothStatus.connected &&
              curr.status == BluetoothStatus.ready,
          listener: (context, state) {
            _awaitingReconnect = true;
            showInfoSnackBar(context, 'Device disconnected. Reconnecting...');
          },
        ),
        // Detect successful auto-reconnect
        BlocListener<BluetoothBloc, BluetoothState>(
          listenWhen: (prev, curr) =>
              !prev.isConnected && curr.isConnected,
          listener: (context, state) {
            if (_awaitingReconnect) {
              _awaitingReconnect = false;
              showSuccessSnackBar(context, 'Reconnected to device');
            }
          },
        ),
      ],
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: const _BottomNavBar(),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _calculateSelectedIndex(location);
    final brightness = Theme.of(context).brightness;
    final containerColor = AppColors.secondaryBackground(brightness);
    final selectedColor = AppColors.primary;
    final unselectedColor = AppColors.secondaryText(brightness);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      child: Container(
        width: double.infinity,
        height: 69.0,
        decoration: BoxDecoration(
          color: containerColor,
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
                label: 'Home',
                isSelected: currentIndex == 0,
                onTap: () => _onItemTapped(context, 0),
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
              ),
              _BluetoothNavIcon(
                label: 'Bluetooth',
                isSelected: currentIndex == 1,
                onTap: () => _onItemTapped(context, 1),
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
              ),
              _NavIcon(
                icon: Icons.person_rounded,
                label: 'Account',
                isSelected: currentIndex == 2,
                onTap: () => _onItemTapped(context, 2),
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
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
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color unselectedColor;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.selectedColor,
    required this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: InkWell(
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: Icon(
          icon,
          color: isSelected ? selectedColor : unselectedColor,
          size: 35.0,
        ),
      ),
    );
  }
}

/// Bluetooth nav icon with connection status (FF style)
class _BluetoothNavIcon extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color unselectedColor;

  const _BluetoothNavIcon({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.selectedColor,
    required this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      buildWhen: (prev, curr) =>
          prev.isConnected != curr.isConnected ||
          prev.isConnecting != curr.isConnecting,
      builder: (context, state) {
        final IconData icon;
        final Color color;

        if (state.isConnected) {
          icon = Icons.bluetooth_connected;
          color = isSelected ? selectedColor : AppColors.success;
        } else if (state.isConnecting) {
          icon = Icons.bluetooth_searching;
          color = isSelected ? selectedColor : unselectedColor;
        } else {
          icon = Icons.bluetooth;
          color = isSelected ? selectedColor : unselectedColor;
        }

        return Semantics(
          label: label,
          button: true,
          selected: isSelected,
          child: InkWell(
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: onTap,
            child: Icon(
              icon,
              color: color,
              size: 35.0,
            ),
          ),
        );
      },
    );
  }
}
