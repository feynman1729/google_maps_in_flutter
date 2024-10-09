import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

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
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};
  final LatLng _initialPosition = LatLng(33.5903,
      130.4017); // 初期位置（緯度33.5903, 経度130.4017: 福岡）を_initialPositionとして定義

  @override
  Widget build(BuildContext context) {
    // アプリのUIを構築
    return Scaffold(
      // アプリバーを表示
      appBar: AppBar(
        title: const Text('Google Maps Directions'),
      ),
      // アプリのボディには、テキストフィールドとGoogleMapウィジェットを表示
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
                zoom: 7,
              ),
              polylines: _polylines,
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
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
    const String apiKey = 'AIzaSyApsx2TXanoD2FbmzLcCfqajqlEPA__B50'; // APIキーを追加
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&mode=driving&key=$apiKey';

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

  // エンコードされたポリラインをデコード
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
