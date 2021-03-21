import 'dart:io';
import 'dart:convert';
import 'package:media_gallery/media_gallery.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_testing/main.dart';
import 'package:image_gallery/image_gallery.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite/tflite.dart';

import 'image_view.dart';

class ImageCategories extends StatefulWidget {
  @override
  _ImageCategoriesState createState() => _ImageCategoriesState();
}

class _ImageCategoriesState extends State<ImageCategories> {
  final String _personCategory = "person";
  final List<String> _streetCategory = [
    "traffic light",
    "truck",
    "bicycle",
    "stop sign"
  ];
  final List<String> _kitchenCategory = [
    "wine glass",
    "cup",
    "fork",
    "knife",
    "spoon",
    "bowl"
  ];
  final List<String> _furnitureCategory = ["chair", "sofa", "bed"];
  final List<String> _animalsCategory = [
    "bird",
    "cat",
    "dog",
    "horse",
    "sheep",
    "cow",
    "elephant",
    "bear",
    "zebra",
    "giraffe"
  ];
  List _images, _alreadyProcessedImages = List();
  List<File> _personImages,
      _streetImages,
      _kitchenImages,
      _furnitureImages,
      _animalImages;
  int _processedImages = 0, _totalImages = 0;
  File _jsonFile;
  Directory _dir;
  String _fileName = "save_file.json", _permissionMsg;
  Map<String, dynamic> _savedContent = Map<String, dynamic>();
  bool _busy = false, _show = false, _showProcessingMsg = false;

  @override
  initState() {
    super.initState();
    _images = new List();
    _personImages = new List<File>();
    _streetImages = new List<File>();
    _kitchenImages = new List<File>();
    _furnitureImages = new List<File>();
    _animalImages = new List<File>();
    setState(() {
      _busy = false;
      _show = false;
      _showProcessingMsg = false;
    });
  }

  Future<void> _askPermission() async {
    PermissionStatus status;
    if (Platform.isIOS)
      status = await Permission.photos.request();
    else
      status = await Permission.storage.request();
    if (status.isGranted) {
      _startProcessing();
    } else if (status.isDenied) {
      String msg = Platform.isIOS 
      ? "Permission to access storage must be granted to proceed.\nGo to Settings > Privacy > Photos, and set permission for this app to Read and Write"
      : "Permission to access storage must be granted to proceed";
      setState(() {
        _permissionMsg = msg;
      });
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _permissionMsg =
            "Permission to access storage must be granted to proceed.\nGo to Settings > Apps & Notifications, and enable Storage permission for this app";
      });
    }
  }

  void _startProcessing() {
    setState(() {
      _busy = true;
    });
    checkSaveFile().then((val) {
      loadModel().then((val) {
        loadImageList().then((value) => {_checkImages()});
      });
    });
  }

  Future<void> checkSaveFile() async {
    Directory directory = await getApplicationDocumentsDirectory();
    _dir = directory;
    _jsonFile = File(_dir.path + "/" + _fileName);
    bool fileExists = await _jsonFile.exists();
    if (!fileExists) {
      _savedContent = {};
      await _jsonFile.create();
    } else {
      String data = await _jsonFile.readAsString();
      if (data.isNotEmpty) {
        _savedContent = json.decode(data);
      }
    }
  }

  Future<void> _writeToFile(String key, String value) async {
    Map<String, dynamic> contentToAdd = {key: value};
    String data = await _jsonFile.readAsString();
    Map<String, dynamic> fileContent = {};
    if (data.isNotEmpty) fileContent = json.decode(data);
    fileContent.addAll(contentToAdd);
    await _jsonFile.writeAsString(json.encode(fileContent));
  }

  loadModel() async {
    Tflite.close();
    try {
      String res;
      res = await Tflite.loadModel(
          model: "assets/tflite/model.tflite",
          labels: "assets/tflite/labels.txt");
      print(res);
    } on PlatformException {
      print("Filed to load the model");
    }
  }

  Future<void> loadImageList() async {
    final List<MediaCollection> collection =
        await MediaGallery.listMediaCollections(mediaTypes: [MediaType.image]);
    final MediaPage imagePage =
        await collection[0].getMedias(mediaType: MediaType.image);
    List<Media> mediaList = imagePage.items;
    List tempImages = [];
    for (Media m in mediaList) {
      File imgFile = await m.getFile();
      String imgPath = imgFile.path;
      tempImages.add(imgPath);
    }

    List tempImgs = List();

    for (var imgPath in tempImages) {
      bool found = false;
      String name = basename(imgPath);
      _savedContent.forEach((key, value) {
        if (key == name) {
          found = true;
          _alreadyProcessedImages.add(imgPath);
        }
      });
      if (!found) tempImgs.add(imgPath);
    }

    this._images = tempImgs;

    setState(() {
      _totalImages = _images.length;
      if (_totalImages > 0) _showProcessingMsg = true;
    });
  }

  _checkImages() async {
    for (var img in _images) {
      await _checkImage(File(img.toString()));
    }
    for (var img in _alreadyProcessedImages) {
      _savedContent.forEach((key, value) async {
        String name = basename(img);
        if (key == name) await _checkClass(value, File(img.toString()));
      });
    }
    setState(() {
      _busy = false;
      _show = true;
      _showProcessingMsg = false;
    });
  }

  Future<void> _checkImage(File img) async {
    setState(() {
      _processedImages += 1;
    });
    var recogs = await Tflite.detectObjectOnImage(
        path: img.path,
        model: "YOLO",
        threshold: 0.3,
        imageMean: 0.0,
        imageStd: 255.0,
        numResultsPerClass: 1);

    if (recogs != null) {
      String currentClass = "";
      double currentConfidence = 0;
      for (var detectedClass in recogs) {
        if (detectedClass["confidenceInClass"] > currentConfidence) {
          currentClass = detectedClass["detectedClass"];
          currentConfidence = detectedClass["confidenceInClass"];
        }
      }
      await _checkClass(currentClass, img);
    }
  }

  Future<void> _checkClass(String imageClass, File img) async {
    await _writeToFile(basename(img.path), imageClass);

    if (imageClass == _personCategory) {
      setState(() {
        _personImages.add(img);
      });
      return;
    }
    if (_checkAvailability(_streetCategory, imageClass)) {
      setState(() {
        _streetImages.add(img);
      });
      return;
    }
    if (_checkAvailability(_kitchenCategory, imageClass)) {
      setState(() {
        _kitchenImages.add(img);
      });
      return;
    }
    if (_checkAvailability(_furnitureCategory, imageClass)) {
      setState(() {
        _furnitureImages.add(img);
      });
      return;
    }
    if (_checkAvailability(_animalsCategory, imageClass)) {
      setState(() {
        _animalImages.add(img);
      });
      return;
    }
  }

  bool _checkAvailability(List<String> category, String imageClass) {
    bool val = false;

    for (String cat in category) {
      if (cat == imageClass) val = true;
    }

    return val;
  }

  void _openImage(BuildContext context, File img) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return ImageView(
        image: img,
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
        appBar: AppBar(
          title: Text("Image Categories"),
        ),
        body: _busy
            ? _getLoadingScreen()
            : (_show
                ? ListView(
                    padding: EdgeInsets.only(left: 10),
                    children: <Widget>[
                      _getHorizontalList("Persons", _personImages, context),
                      _getHorizontalList("Street", _streetImages, context),
                      _getHorizontalList("Kitchen", _kitchenImages, context),
                      _getHorizontalList(
                          "Furniture", _furnitureImages, context),
                      _getHorizontalList("Animals", _animalImages, context),
                    ],
                  )
                : Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.only(left: 10, right: 10, top: 50),
                      child: Container(
                        height: 150,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            RaisedButton(
                              color: Colors.blue,
                              child: Container(
                                alignment: Alignment.center,
                                height: 50,
                                width: double.infinity,
                                child: Text(
                                  "Show Images",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 20),
                                ),
                              ),
                              onPressed: _askPermission,
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            _permissionMsg == null
                                ? SizedBox(
                                    height: 0,
                                  )
                                : Text(
                                    "$_permissionMsg",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.red),
                                  )
                          ],
                        ),
                      ),
                    ),
                  )));
  }

  Widget _getHorizontalList(String title, List list, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: screenHeight * 0.05,
        ),
        Text(
          title,
          style: TextStyle(color: Colors.grey, fontSize: screenWidth * 0.05),
        ),
        SizedBox(
          height: screenHeight * 0.02,
        ),
        Container(
          height: screenHeight * 0.2,
          child: list.length > 0
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Row(
                      children: <Widget>[
                        FlatButton(
                          padding: EdgeInsets.symmetric(horizontal: 0),
                          child: Container(
                            width: screenHeight * 0.2,
                            decoration: BoxDecoration(
                                image: DecorationImage(
                                    image: FileImage(list[index]),
                                    fit: BoxFit.cover)),
                          ),
                          onPressed: () {
                            _openImage(context, list[index]);
                          },
                        ),
                        SizedBox(
                          width: screenWidth * 0.02,
                        )
                      ],
                    );
                  },
                )
              : Center(
                  child: Text(
                    "No image found for this category",
                    style: TextStyle(
                        color: Colors.grey, fontSize: screenWidth * 0.03),
                  ),
                ),
        ),
        SizedBox(
          height: screenHeight * 0.03,
        ),
        Center(
          child: Container(
            height: screenHeight * 0.001,
            width: screenWidth * 0.5,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _getLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(
            height: screenHeight * 0.05,
          ),
          _showProcessingMsg
              ? Text(
                  "Processing image ($_processedImages/$_totalImages)",
                  style: TextStyle(
                      color: Colors.grey, fontSize: screenWidth * 0.04),
                )
              : SizedBox(
                  height: 0,
                ),
        ],
      ),
    );
  }
}
