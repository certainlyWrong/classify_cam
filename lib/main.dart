import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/src/media_type.dart';

late List<CameraDescription> _cameras;

String url = '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _cameras = await availableCameras();
  runApp(const AppWidget());
}

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const CameraApp(),
      theme: ThemeData.dark(),
    );
  }
}

/// CameraApp is the Main Application.
class CameraApp extends StatefulWidget {
  /// Default Constructor
  const CameraApp({super.key});

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController controller;
  String bodyResponse = '';

  @override
  void initState() {
    super.initState();
    controller = CameraController(
      _cameras[0],
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    controller.initialize().then((_) {
      if (!mounted) {
        controller.setFlashMode(FlashMode.off);
        return;
      }
      setState(() {});
    }).catchError(
      (Object e) {
        if (e is CameraException) {
          switch (e.code) {
            case 'CameraAccessDenied':
              // Handle access errors here.
              break;
            default:
              // Handle other errors here.
              break;
          }
        }
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Material(
      child: CameraPreview(
        controller,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ElevatedButton(
                    onPressed: () {
                      controller.takePicture().then(
                        (file) {
                          file.readAsBytes().then(
                            (fileBytes) {
                              try {
                                log('$url/predict');
                                final request = http.MultipartRequest(
                                    'POST', Uri.parse('$url/predict'))
                                  ..files.add(
                                    http.MultipartFile.fromBytes(
                                      'image',
                                      fileBytes,
                                      filename: 'image.jpg',
                                      contentType: MediaType('image', 'jpeg'),
                                    ),
                                  );

                                request.send().then(
                                  (value) {
                                    http.Response.fromStream(value).then(
                                      (value) {
                                        if (value.statusCode != 200) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  "Server not responding."),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(value.body),
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
                                ).catchError(
                                  (e) {
                                    log("Erro ao enviar a imagem.");
                                  },
                                );
                              } catch (e) {
                                log("Erro ao enviar a imagem.");
                              }
                            },
                          );
                        },
                      );
                    },
                    child: const Icon(Icons.camera),
                  ),
                ),
              ),
              // setting button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsWidgets(
                            controller: controller,
                          ),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.settings,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsWidgets extends StatefulWidget {
  final CameraController controller;
  const SettingsWidgets({super.key, required this.controller});

  @override
  State<SettingsWidgets> createState() => _SettingsWidgetsState();
}

class _SettingsWidgetsState extends State<SettingsWidgets> {
  late final textController = TextEditingController();
  @override
  void initState() {
    textController.text = url;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(10.0)),
            SizedBox(
              width: 130.0,
              child: ElevatedButton(
                onPressed: () {
                  if (widget.controller.value.flashMode == FlashMode.off) {
                    widget.controller.setFlashMode(FlashMode.always);
                  } else if (widget.controller.value.flashMode ==
                      FlashMode.always) {
                    widget.controller.setFlashMode(FlashMode.auto);
                  } else {
                    widget.controller.setFlashMode(FlashMode.off);
                  }
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const Text('Flash'),
                    widget.controller.value.flashMode == FlashMode.off
                        ? const Icon(Icons.flash_off)
                        : widget.controller.value.flashMode == FlashMode.always
                            ? const Icon(Icons.flash_on)
                            : const Icon(Icons.flash_auto),
                  ],
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.all(10.0)),
            SizedBox(
              width: MediaQuery.of(context).size.width - 20.0,
              child: TextField(
                controller: textController,
                onTapOutside: (event) {
                  FocusScope.of(context).unfocus();
                },
                decoration: const InputDecoration(
                  labelText: 'Url',
                  hintText: 'Enter the url to classify the image.',
                ),
                onChanged: (value) {
                  url = value;
                },
              ),
            ),
            const Padding(padding: EdgeInsets.all(10.0)),
            SizedBox(
              width: 130.0,
              child: ElevatedButton(
                onPressed: () {
                  http.get(Uri.parse(url)).then(
                    (value) {
                      if (value.statusCode != 200) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Server not responding."),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(value.body),
                          ),
                        );
                      }
                    },
                  ).catchError(
                    (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Server not responding."),
                        ),
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: const Text('Ping Server'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
