import '../../shared/domain/smart_home_repository.dart';
import '../../shared/models/models.dart';
import 'app_routes.dart';

/// Validates and resolves user-selected launch routes.
class StartRouteSupport {
  StartRouteSupport._();

  static Future<String> validate(
    SmartHomeRepository repo,
    String route,
  ) async {
    if (route == Paths.home) return Paths.home;

    final segments = Uri.parse(route).pathSegments;
    if (segments.length < 3 || segments.first != 'home') {
      return Paths.home;
    }

    switch (segments[1]) {
      case 'house':
        final house = await repo.getHouse(segments[2]);
        return house != null ? route : Paths.home;
      case 'floor':
        final floor = await repo.getFloor(segments[2]);
        return floor != null ? route : Paths.home;
      case 'room':
        final room = await repo.getRoom(segments[2]);
        return room != null ? route : Paths.home;
      case 'device':
        final device = await repo.getDevice(segments[2]);
        return device != null ? route : Paths.home;
      default:
        return Paths.home;
    }
  }

  static Future<String> resolveLabel(
    SmartHomeRepository repo,
    String route,
  ) async {
    if (route == Paths.home) return 'Home';

    final segments = Uri.parse(route).pathSegments;
    if (segments.length < 3 || segments.first != 'home') return 'Home';

    switch (segments[1]) {
      case 'house':
        final house = await repo.getHouse(segments[2]);
        return house != null ? '${house.name} · Etagen' : 'Home';
      case 'floor':
        final floor = await repo.getFloor(segments[2]);
        return floor != null ? '${floor.name} · Räume' : 'Home';
      case 'room':
        final room = await repo.getRoom(segments[2]);
        return room != null ? '${room.name} · Raum-Übersicht' : 'Home';
      case 'device':
        final device = await repo.getDevice(segments[2]);
        return device != null
            ? '${device.displayName} · Geräte-Übersicht'
            : 'Home';
      default:
        return 'Home';
    }
  }
}
