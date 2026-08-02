/// Local-first portfolio mode. The run script supplies the Mac's LAN address
/// for a physical device, while simulators can use the default loopback URL.
const bool portfolioDemo = bool.fromEnvironment(
  'PORTFOLIO_DEMO',
  defaultValue: true,
);

const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8010',
);

/// Social providers are intentionally disabled in portfolio mode. Supply new
/// keys only when deliberately running a non-demo build.
const String kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
const String kakaoJavaScriptAppKey = String.fromEnvironment(
  'KAKAO_JAVASCRIPT_APP_KEY',
);
