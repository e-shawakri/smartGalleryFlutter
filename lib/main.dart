import 'package:flutter/material.dart';
import 'package:flutter_testing/image_categories.dart';

void main() {
  runApp(MyApp());
}

double screenWidth, screenHeight;

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    
    return MaterialApp(
      home: ImageCategories(),
    );
  }
}

