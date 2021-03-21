import 'dart:io';
import 'package:flutter/material.dart';

class ImageView extends StatelessWidget {
  final File image;

  const ImageView({Key key,@required this.image}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Image Preview"),
      ),
      body: Center(child: Image.file(image)),
    );
  }
}