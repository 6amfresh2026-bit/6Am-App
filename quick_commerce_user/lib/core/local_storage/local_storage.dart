/// Key–value persistence abstraction. Callers never see shared_preferences.
abstract interface class LocalStorage {
  String? getString(String key);
  Future<void> setString(String key, String value);

  bool? getBool(String key);
  Future<void> setBool(String key, bool value);

  List<String> getStringList(String key);
  Future<void> setStringList(String key, List<String> value);

  Future<void> remove(String key);
}

/// Every persisted key in one place — avoids silent typos across features.
abstract final class StorageKeys {
  static const accessToken = 'auth.access_token';
  static const refreshToken = 'auth.refresh_token';
  static const userJson = 'auth.user';
  static const onboardingSeen = 'app.onboarding_seen';
  static const themeMode = 'app.theme_mode';
  static const themeFlavor = 'app.theme_flavor';
  static const selectedAddressId = 'app.selected_address_id';

  /// Ids of customers already shown the "where should we deliver?" prompt, so
  /// it is offered once per account rather than on every app open. Keyed by
  /// user so a second account on the same device still gets asked.
  static const locationPromptedUserIds = 'app.location_prompted_user_ids';
  static const recentSearches = 'search.recent';
  static const recentlyViewed = 'catalog.recently_viewed';
  static const cachedCart = 'cart.cached';
  static const notificationsEnabled = 'settings.notifications';
}
