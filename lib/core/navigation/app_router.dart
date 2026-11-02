import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/add_device/presentation/new_device_wizard_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/devices/presentation/device_data_page.dart';
import '../../features/devices/presentation/device_parameters_page.dart';
import '../../features/devices/presentation/led_strip_settings_page.dart';
import '../../features/devices/presentation/smart_led_strips_page.dart';
import '../../features/devices/presentation/smart_led_triggers_page.dart';
import '../../features/devices/presentation/change_password_page.dart';
import '../../features/devices/presentation/cloud_page.dart';
import '../../features/devices/presentation/date_time_page.dart';
import '../../features/devices/presentation/device_details_page.dart';
import '../../features/devices/presentation/ems_history_page.dart';
import '../../features/devices/presentation/device_info_page.dart';
import '../../features/devices/presentation/device_location_page.dart';
import '../../features/devices/presentation/device_settings_page.dart';
import '../../features/devices/presentation/general_settings_page.dart';
import '../../features/devices/presentation/matter_page.dart';
import '../../features/devices/presentation/mqtt_cloud_page.dart';
import '../../features/devices/presentation/network_page.dart';
import '../../features/devices/presentation/update_settings_page.dart';
import '../../features/devices/presentation/virtumi_cloud_page.dart';
import '../../features/floors/presentation/floors_page.dart';
import '../../features/home/presentation/all_houses_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/people/presentation/people_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/rooms/presentation/room_overview_page.dart';
import '../../features/rooms/presentation/rooms_page.dart';
import '../../features/scenes/presentation/scenes_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/start_screen_picker_page.dart';
import '../supabase/supabase_client.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'go_router_refresh_stream.dart';
import 'page_transitions.dart';
import 'start_route_providers.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final redirectTrigger = ref.watch(routerRedirectTriggerProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Paths.home,
    refreshListenable: Listenable.merge([
      GoRouterRefreshStream(client.auth.onAuthStateChange),
      redirectTrigger,
    ]),
    redirect: (context, state) {
      final session = client.auth.currentSession;
      final isLoggedIn = session != null;
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/register';

      if (!isLoggedIn) {
        resetStartRouteSessionState(ref);
        if (!isAuthRoute) return '/login';
        return null;
      }

      final startRoute = ref.read(effectiveStartRouteProvider);
      final settingsReady = ref.read(appSettingsReadyProvider);
      final startApplied = ref.read(startRouteAppliedProvider);

      if (isAuthRoute) {
        if (!settingsReady) return Paths.home;
        ref.read(startRouteAppliedProvider.notifier).markApplied();
        return startRoute;
      }

      if (settingsReady && !startApplied && location == Paths.home) {
        ref.read(startRouteAppliedProvider.notifier).markApplied();
        if (startRoute != Paths.home) return startRoute;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: AppRoute.login,
        pageBuilder: (context, state) => fadePage(state, const LoginPage()),
      ),
      GoRoute(
        path: '/register',
        name: AppRoute.register,
        pageBuilder: (context, state) => fadePage(state, const RegisterPage()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Paths.home,
                name: AppRoute.home,
                pageBuilder: (context, state) =>
                    fadePage(state, const HomePage()),
                routes: [
                  GoRoute(
                    path: 'add-device',
                    name: AppRoute.newDeviceWizard,
                    pageBuilder: (context, state) => slidePage(
                      state,
                      const NewDeviceWizardPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'houses',
                    name: AppRoute.allHouses,
                    pageBuilder: (context, state) => slidePage(
                      state,
                      const AllHousesPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'house/:houseId',
                    name: AppRoute.floors,
                    pageBuilder: (context, state) => slidePage(
                      state,
                      FloorsPage(houseId: state.pathParameters['houseId']!),
                    ),
                  ),
                  GoRoute(
                    path: 'floor/:floorId',
                    name: AppRoute.rooms,
                    pageBuilder: (context, state) => slidePage(
                      state,
                      RoomsPage(floorId: state.pathParameters['floorId']!),
                    ),
                  ),
                  GoRoute(
                    path: 'room/:roomId',
                    name: AppRoute.roomOverview,
                    pageBuilder: (context, state) => slidePage(
                      state,
                      RoomOverviewPage(roomId: state.pathParameters['roomId']!),
                    ),
                  ),
                  GoRoute(
                    path: 'device/:deviceId',
                    name: AppRoute.deviceDetails,
                    pageBuilder: (context, state) => slidePage(
                      state,
                      DeviceDetailsPage(
                        deviceId: state.pathParameters['deviceId']!,
                      ),
                    ),
                    routes: _deviceSettingRoutes(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Paths.scenes,
              name: AppRoute.scenes,
              pageBuilder: (context, state) =>
                  fadePage(state, const ScenesPage()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Paths.people,
              name: AppRoute.people,
              pageBuilder: (context, state) =>
                  fadePage(state, const PeoplePage()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Paths.settings,
              name: AppRoute.settings,
              pageBuilder: (context, state) =>
                  fadePage(state, const SettingsPage()),
              routes: [
                GoRoute(
                  path: 'profile',
                  name: AppRoute.profile,
                  pageBuilder: (context, state) =>
                      slidePage(state, const ProfilePage()),
                ),
                GoRoute(
                  path: 'start-screen',
                  name: AppRoute.startScreen,
                  pageBuilder: (context, state) => slidePage(
                    state,
                    const StartScreenPickerPage(),
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});

List<GoRoute> _deviceSettingRoutes() {
  String id(GoRouterState s) => s.pathParameters['deviceId']!;
  return [
    GoRoute(
      path: 'settings',
      name: AppRoute.deviceSettings,
      pageBuilder: (c, s) => slidePage(s, DeviceSettingsPage(deviceId: id(s))),
    ),
    GoRoute(
      path: 'info',
      name: AppRoute.deviceInfo,
      pageBuilder: (c, s) => slidePage(s, DeviceInfoPage(deviceId: id(s))),
    ),
    GoRoute(
      path: 'datetime',
      name: AppRoute.dateTime,
      pageBuilder: (c, s) => slidePage(s, DateTimePage(deviceId: id(s))),
    ),
    GoRoute(
      path: 'network',
      name: AppRoute.network,
      pageBuilder: (c, s) => slidePage(s, NetworkPage(deviceId: id(s))),
    ),
    GoRoute(
      path: 'matter',
      name: AppRoute.matter,
      pageBuilder: (c, s) => slidePage(s, MatterPage(deviceId: id(s))),
    ),
    GoRoute(
      path: 'cloud',
      name: AppRoute.cloud,
      pageBuilder: (c, s) => slidePage(s, CloudPage(deviceId: id(s))),
      routes: [
        GoRoute(
          path: 'virtumi',
          name: AppRoute.virtumiCloud,
          pageBuilder: (c, s) =>
              slidePage(s, VirtumiCloudPage(deviceId: id(s))),
        ),
        GoRoute(
          path: 'mqtt',
          name: AppRoute.mqttCloud,
          pageBuilder: (c, s) => slidePage(s, MqttCloudPage(deviceId: id(s))),
        ),
      ],
    ),
    GoRoute(
      path: 'location',
      name: AppRoute.deviceLocation,
      pageBuilder: (c, s) => slidePage(s, DeviceLocationPage(deviceId: id(s))),
    ),
    GoRoute(
      path: 'password',
      name: AppRoute.changePassword,
      pageBuilder: (c, s) => slidePage(s, ChangePasswordPage(deviceId: id(s))),
    ),
    GoRoute(
      path: 'update',
      name: AppRoute.updateSettings,
      pageBuilder: (c, s) => slidePage(s, UpdateSettingsPage(deviceId: id(s))),
    ),
    GoRoute(
      path: 'general',
      name: AppRoute.generalSettings,
      pageBuilder: (c, s) => slidePage(s, GeneralSettingsPage(deviceId: id(s))),
      routes: [
        GoRoute(
          path: 'led-strip-settings',
          name: AppRoute.ledStripSettings,
          pageBuilder: (c, s) =>
              slidePage(s, LedStripSettingsPage(deviceId: id(s))),
        ),
      ],
    ),
    GoRoute(
      path: 'parameters',
      name: AppRoute.deviceParameters,
      pageBuilder: (c, s) => slidePage(s, DeviceParametersPage(deviceId: id(s))),
    ),
    GoRoute(
      path: 'led-strips',
      name: AppRoute.smartLedStrips,
      pageBuilder: (c, s) => slidePage(s, SmartLedStripsPage(deviceId: id(s))),
    ),
    GoRoute(
      path: 'led-triggers',
      name: AppRoute.smartLedTriggers,
      pageBuilder: (c, s) => slidePage(s, SmartLedTriggersPage(deviceId: id(s))),
    ),
    GoRoute(
      path: 'sensor-data',
      name: AppRoute.deviceData,
      pageBuilder: (c, s) => slidePage(s, DeviceDataPage(deviceId: id(s))),
    ),
    GoRoute(
      path: 'history',
      name: AppRoute.emsHistory,
      pageBuilder: (c, s) => slidePage(s, EmsHistoryPage(deviceId: id(s))),
    ),
  ];
}
