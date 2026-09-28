/// Every route path and name in the app. Deep-link shaped
/// (`/product/:id`, `/category/:id`) so external links resolve.
abstract final class RoutePaths {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const otp = '/otp';
  static const register = '/register';
  static const addressSelection = '/address/select';

  // Shell tabs
  static const home = '/home';
  static const categories = '/categories';
  static const cart = '/cart';
  static const orders = '/orders';
  static const profile = '/profile';

  static const search = '/search';
  static const subCategory = '/category/:id';
  static const brands = '/brands';
  static const productListing = '/products';
  static const productDetails = '/product/:id';
  static const wishlist = '/wishlist';
  static const wallet = '/wallet';
  static const checkout = '/checkout';
  static const coupons = '/coupons';
  static const payment = '/payment';
  static const addresses = '/addresses';
  static const notifications = '/notifications';
  static const monthlyLists = '/monthly-lists';
  static const monthlyListDetails = '/monthly-lists/:id';
  static const subscriptions = '/subscriptions';
  static const subscriptionDetails = '/subscriptions/:id';
  static const orderSuccess = '/order/success';
  static const orderTracking = '/order/:id/track';
  static const orderChat = '/order/:id/chat';
  static const orderDetails = '/order/:id';
  static const editProfile = '/profile/edit';
  static const help = '/profile/help';
  static const settings = '/profile/settings';
  static const privacyPolicy = '/profile/privacy';
  static const terms = '/profile/terms';
  static const about = '/profile/about';

  static String subCategoryOf(String categoryId) => '/category/$categoryId';
  static String productDetailsOf(String productId) => '/product/$productId';
  static String orderDetailsOf(String orderId) => '/order/$orderId';
  static String orderTrackingOf(String orderId) => '/order/$orderId/track';
  static String orderChatOf(String orderId) => '/order/$orderId/chat';
  static String monthlyListDetailsOf(String listId) => '/monthly-lists/$listId';
  static String subscriptionDetailsOf(String id) => '/subscriptions/$id';
}

abstract final class RouteNames {
  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const login = 'login';
  static const otp = 'otp';
  static const register = 'register';
  static const addressSelection = 'addressSelection';
  static const home = 'home';
  static const categories = 'categories';
  static const cart = 'cart';
  static const orders = 'orders';
  static const profile = 'profile';
  static const search = 'search';
  static const subCategory = 'subCategory';
  static const brands = 'brands';
  static const productListing = 'productListing';
  static const productDetails = 'productDetails';
  static const wishlist = 'wishlist';
  static const wallet = 'wallet';
  static const checkout = 'checkout';
  static const coupons = 'coupons';
  static const payment = 'payment';
  static const addresses = 'addresses';
  static const notifications = 'notifications';
  static const monthlyLists = 'monthlyLists';
  static const monthlyListDetails = 'monthlyListDetails';
  static const subscriptions = 'subscriptions';
  static const subscriptionDetails = 'subscriptionDetails';
  static const orderSuccess = 'orderSuccess';
  static const orderTracking = 'orderTracking';
  static const orderChat = 'orderChat';
  static const orderDetails = 'orderDetails';
  static const editProfile = 'editProfile';
  static const help = 'help';
  static const settings = 'settings';
  static const privacyPolicy = 'privacyPolicy';
  static const terms = 'terms';
  static const about = 'about';
}
