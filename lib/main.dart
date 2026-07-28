import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const GeoPointApp());
}

class GeoPointApp extends StatelessWidget {
  const GeoPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GeoPoint',
      theme: ThemeData.dark(),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {

  LatLng? selectedPoint;

  // Position réelle de Tokyo
  final LatLng tokyo = LatLng(35.6762, 139.6503);


  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: FlutterMap(

        options: MapOptions(

          initialCenter: LatLng(20, 0),
          initialZoom: 2,


          // CLIC SUR LA CARTE
          onTap: (tapPosition, point) {

            setState(() {
              selectedPoint = point;
            });


            final distance = const Distance().as(
              LengthUnit.Kilometer,
              point,
              tokyo,
            );


            print("======================");
            print("POINT JOUEUR");
            print("Latitude : ${point.latitude}");
            print("Longitude : ${point.longitude}");
            print("DISTANCE TOKYO : ${distance.toStringAsFixed(0)} km");
            print("======================");

          },

        ),


        children: [


          TileLayer(
            urlTemplate:
            'https://basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}.png',

            userAgentPackageName:
            'com.example.geopoint',
          ),



          MarkerLayer(

            markers: selectedPoint == null

                ? []

                : [

              Marker(

                point: selectedPoint!,

                width: 50,

                height: 50,

                child: const Icon(

                  Icons.location_on,

                  color: Colors.red,

                  size: 50,

                ),

              ),

            ],

          ),


        ],

      ),

    );

  }

}
