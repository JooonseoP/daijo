import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;

import '../../domain/entities/store.dart';

const double kDefaultGeofenceRadiusMeters = 150.0;

class StoreSeedLoader {
  StoreSeedLoader(this._bundle,
      {this.assetPath = 'assets/data/daiso_stores.json'});

  final AssetBundle _bundle;
  final String assetPath;

  Future<List<Store>> load() async {
    final raw = await _bundle.loadString(assetPath);
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => _fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Store _fromJson(Map<String, dynamic> j) => Store(
        id: j['id'].toString(),
        name: j['name'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        radius: kDefaultGeofenceRadiusMeters,
      );
}
