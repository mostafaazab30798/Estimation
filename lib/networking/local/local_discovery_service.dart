// lib/networking/local/local_discovery_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:nsd/nsd.dart' as nsd;

class DiscoveredRoom {
  final String hostName;
  final String ip;
  final int port;
  final String gameType;
  final int currentPlayers;
  final int maxPlayers;
  final String roomCode;

  DiscoveredRoom({
    required this.hostName,
    required this.ip,
    required this.port,
    required this.gameType,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.roomCode,
  });
}

class LocalDiscoveryService {
  static const String serviceType = '_pocketest._tcp';
  nsd.Registration? _registration;
  nsd.Discovery? _discovery;

  /// Helper to fetch host local IP address on WiFi / Hotspot
  static Future<String?> getLocalIpAddress() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty && wifiIp != '0.0.0.0') {
        return wifiIp;
      }

      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback &&
              (addr.address.startsWith('192.168.') ||
                  addr.address.startsWith('10.') ||
                  addr.address.startsWith('172.'))) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalDiscovery] Error resolving IP: $e');
    }
    return null;
  }

  /// Start mDNS broadcast for hosted game room
  Future<void> startBroadcasting({
    required String hostName,
    required int port,
    required String gameType,
    required String roomCode,
    int currentPlayers = 1,
    int maxPlayers = 4,
  }) async {
    await stopBroadcasting();
    try {
      final service = nsd.Service(
        name: 'PocketEstimation_$roomCode',
        type: serviceType,
        port: port,
        txt: {
          'hostName': Uint8List.fromList(utf8.encode(hostName)),
          'gameType': Uint8List.fromList(utf8.encode(gameType)),
          'roomCode': Uint8List.fromList(utf8.encode(roomCode)),
          'currentPlayers': Uint8List.fromList(utf8.encode('$currentPlayers')),
          'maxPlayers': Uint8List.fromList(utf8.encode('$maxPlayers')),
        },
      );

      _registration = await nsd.register(service);
      debugPrint('[LocalDiscovery] mDNS service registered for $hostName on port $port');
    } catch (e) {
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('[LocalDiscovery] Native mDNS plugin missing (requires full app rebuild after pubspec edit): $e');
      } else {
        debugPrint('[LocalDiscovery] mDNS broadcast registration failed: $e');
      }
    }
  }

  /// Stop mDNS broadcasting
  Future<void> stopBroadcasting() async {
    if (_registration != null) {
      try {
        await nsd.unregister(_registration!);
      } catch (e) {
        debugPrint('[LocalDiscovery] Unregister error: $e');
      }
      _registration = null;
    }
  }

  /// Start mDNS discovery stream for nearby local games
  Stream<List<DiscoveredRoom>> startScan() {
    final controller = StreamController<List<DiscoveredRoom>>();
    final List<DiscoveredRoom> rooms = [];

    () async {
      try {
        _discovery = await nsd.startDiscovery(serviceType);
        _discovery!.addListener(() {
          rooms.clear();
          for (final service in _discovery!.services) {
            try {
              final txtMap = service.txt ?? {};
              String getTxtValue(String key) {
                final bytes = txtMap[key];
                if (bytes != null && bytes.isNotEmpty) {
                  return utf8.decode(bytes);
                }
                return '';
              }

              final hostName = getTxtValue('hostName');
              final gameType = getTxtValue('gameType');
              final roomCode = getTxtValue('roomCode');
              final currentPlayers = int.tryParse(getTxtValue('currentPlayers')) ?? 1;
              final maxPlayers = int.tryParse(getTxtValue('maxPlayers')) ?? 4;

              final addresses = service.addresses;
              String ip = service.host ?? '';
              if (addresses != null && addresses.isNotEmpty) {
                ip = addresses.first.address;
              }

              if (ip.isNotEmpty && service.port != null) {
                rooms.add(DiscoveredRoom(
                  hostName: hostName.isNotEmpty ? hostName : (service.name ?? 'غرفة محلي'),
                  ip: ip,
                  port: service.port!,
                  gameType: gameType.isNotEmpty ? gameType : 'kotchina',
                  currentPlayers: currentPlayers,
                  maxPlayers: maxPlayers,
                  roomCode: roomCode.isNotEmpty ? roomCode : 'LOCAL',
                ));
              }
            } catch (e) {
              debugPrint('[LocalDiscovery] Parsing service error: $e');
            }
          }
          if (!controller.isClosed) {
            controller.add(List.from(rooms));
          }
        });
      } catch (e) {
        debugPrint('[LocalDiscovery] Discovery start error: $e');
      }
    }();

    controller.onCancel = () {
      stopScan();
    };

    return controller.stream;
  }

  /// Stop mDNS discovery
  Future<void> stopScan() async {
    if (_discovery != null) {
      try {
        await nsd.stopDiscovery(_discovery!);
      } catch (e) {
        debugPrint('[LocalDiscovery] Stop discovery error: $e');
      }
      _discovery = null;
    }
  }
}
