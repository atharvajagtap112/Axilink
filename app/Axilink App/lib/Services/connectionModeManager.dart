enum ConnectionMode { cloud, localWifi }

class ConnectionModeManager {
  static final ConnectionModeManager _instance = ConnectionModeManager._internal();
  factory ConnectionModeManager() => _instance;
  ConnectionModeManager._internal();

  ConnectionMode _mode = ConnectionMode.cloud;
  String?  _customLocalIP;

  ConnectionMode get mode => _mode;
  String? get customLocalIP => _customLocalIP;

  void setMode(ConnectionMode mode) {
    _mode = mode;
  }

  void setCustomLocalIP(String?  ip) {
    _customLocalIP = ip;
  }

  bool get isCloudMode => _mode == ConnectionMode.cloud;
  bool get isLocalWifiMode => _mode == ConnectionMode. localWifi;
}