import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'src/locations.dart' as locations;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // マーカーを保持するマップの空配列を定義
  final Map<String, Marker> _markers = {};

  // 初期位置（緯度33.5903, 経度130.4017: 福岡）を_initialPositionとして定義
  final LatLng _initialPosition = LatLng(33.5903, 130.4017);

  Future<void> _onMapCreated(GoogleMapController controller) async {
    // getGoogleOffices()関数を使ってGoogleのオフィスの位置情報を取得
    final googleOffices = await locations.getGoogleOffices();
    setState(() {
      // マーカーをクリア
      _markers.clear();
      // Googleのオフィスの位置情報を元にマーカーを作成
      for (final office in googleOffices.offices) {
        // マーカーを作成
        final marker = Marker(
          markerId: MarkerId(office.name), // マーカーID
          position: LatLng(office.lat, office.lng), // マーカーの位置
          infoWindow: InfoWindow(
            // マーカーをタップしたときに表示される情報ウィンドウ
            title: office.name, // タイトル
            snippet: office.address, // 詳細
          ),
        );
        _markers[office.name] = marker; // マーカーをマーカーリストに追加
      }
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        // MaterialAppを返す
        home: Scaffold(
          // Scaffoldを返す
          appBar: AppBar(
            // AppBarを返す
            title: const Text('Google Office Locations'), // タイトル
            backgroundColor: Colors.green[700], // 背景色
          ),
          body: GoogleMap(
            // GoogleMapを返す
            onMapCreated: _onMapCreated, // マップが作成されたときに呼び出される関数
            initialCameraPosition: CameraPosition(
              // カメラの初期位置を指定
              target: _initialPosition, // ここで初期位置を指定
              zoom: 14.0, // ズームレベル
            ),
            markers: _markers.values.toSet(), // マーカーをセット
          ),
        ),
      );
}
