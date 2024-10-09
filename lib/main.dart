import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:math';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MapSample(),
    );
  }
}

class MapSample extends StatefulWidget {
  @override
  State<MapSample> createState() => MapSampleState();
}

class MapSampleState extends State<MapSample> {
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};
  final Map<String, Marker> _markers = {};
  final LatLng _initialPosition = LatLng(33.5903, 130.4017); // 福岡

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Maps Directions'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startController,
                    decoration: InputDecoration(hintText: '出発地点'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: endController,
                    decoration: InputDecoration(hintText: '目的地'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _onSearchPressed,
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 14.0,
              ),
              markers: _markers.values.toSet(),
              polylines: _polylines,
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    final googleOffices = await locations.getGoogleOffices();
    setState(() {
      _markers.clear();
      for (final office in googleOffices.offices) {
        final marker = Marker(
          markerId: MarkerId(office.name),
          position: LatLng(office.lat, office.lng),
          infoWindow: InfoWindow(
            title: office.name,
            snippet: office.address,
          ),
        );
        _markers[office.name] = marker;
      }
    });
  }

  // ルート検索ボタンを押した時の処理
  void _onSearchPressed() async {
    final start = startController.text;
    final end = endController.text;
    if (start.isEmpty || end.isEmpty) {
      return; // 空の入力を無視
    }
    await _getDirections(start, end); // Directions APIを呼び出してルートを取得
  }

  // Google Directions APIを使ってルートを取得し、ポリラインを描画
  Future<void> _getDirections(String origin, String destination) async {
    const String apiKey = 'AIzaSyApsx2TXanoD2FbmzLcCfqajqlEPA__B50'; // APIキー
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&mode=walking&alternatives=true&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'].isNotEmpty) {
        final points =
            _decodePolyline(data['routes'][0]['overview_polyline']['points']);

        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: PolylineId('directions'),
            points: points,
            color: Colors.blue,
            width: 5,
          ));

          // カメラをルートに合わせてズーム
          _mapController.animateCamera(
            CameraUpdate.newLatLngBounds(
              _getBounds(points),
              50, // パディング
            ),
          );
        });
      }
    } else {
      throw Exception('Failed to load directions');
    }
  }

  // Google Elevation APIを使用して標高を取得し、勾配を計算
  Future<void> _calculateGradient() async {
    if (_routePoints.isEmpty) return;

    final String path = _routePoints
        .map((point) => '${point.latitude},${point.longitude}')
        .join('|');
    final String elevationUrl =
        'https://maps.googleapis.com/maps/api/elevation/json?path=$path&samples=${_routePoints.length}&key=$apiKey';

    final elevationResponse = await http.get(Uri.parse(elevationUrl));
    if (elevationResponse.statusCode == 200) {
      final elevationData = json.decode(elevationResponse.body);
      if (elevationData['results'].isNotEmpty) {
        double totalGradient = 0.0;

        // ルート全体の勾配を計算
        for (int i = 1; i < elevationData['results'].length; i++) {
          final elevation1 = elevationData['results'][i - 1]['elevation'];
          final elevation2 = elevationData['results'][i]['elevation'];
          final distance =
              _calculateDistance(_routePoints[i - 1], _routePoints[i]);

          final gradient = ((elevation2 - elevation1) / distance) * 100;
          totalGradient += gradient;
        }

        final averageGradient = totalGradient / (_routePoints.length - 1);
        print('平均勾配: $averageGradient%');
      }
    }
  }

  // 2地点間の距離を計算（Haversine Formula）
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // 地球の半径（キロメートル）
    final double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final double dLng = _degreesToRadians(point2.longitude - point1.longitude);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(point1.latitude)) *
            cos(_degreesToRadians(point2.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Google Directions APIから返されたエンコードされたポリラインをデコード
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  // ルート全体を含む境界を計算
  LatLngBounds _getBounds(List<LatLng> points) {
    final double southWestLat =
        points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final double southWestLng =
        points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final double northEastLat =
        points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final double northEastLng =
        points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    return LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );
  }
}
