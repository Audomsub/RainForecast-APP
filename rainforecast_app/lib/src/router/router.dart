// import 'package:flutter/material.dart';
// import 'package:rainforecast_app/main.dart';
// import 'package:rainforecast_app/src/map/mainmap.dart';

// class RouterLink extends StatelessWidget {
//   const RouterLink({super.key});

//   @override
//   Widget build(BuildContext context) {
//     // 1. Use MaterialApp, not Material
//     return MaterialApp(
//       title: 'Rain Forecast App',
      
//       // 2. Define the starting route
//       initialRoute: '/', 
      
//       // 3. Define the route table
//       routes: {
//         // When navigating to '/', show MyApp (Home)
//         '/': (context) => const MyApp(),
        
//         // When navigating to '/map', show MainMap
//         // Use a simple string name, not the file path
//         '/map': (context) => const MainMap(),
//       },
//     );
//   }
// }