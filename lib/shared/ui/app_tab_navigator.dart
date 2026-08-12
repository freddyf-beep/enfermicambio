import 'package:flutter/foundation.dart';

/// Lets any widget request a switch of the bottom navigation tab
/// (e.g. a notification tapping into RANKING or JUEGO). The shell listens
/// and updates its selected index.
abstract final class AppTabNavigator {
  static final ValueNotifier<int?> requests = ValueNotifier<int?>(null);

  static void goTo(int tab) => requests.value = tab;
}
