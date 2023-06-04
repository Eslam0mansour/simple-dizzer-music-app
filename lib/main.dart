import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Plugin must be initialized before using
  await FlutterDownloader.initialize(
      debug: true // optional: set false to disable printing logs to console
      );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
       colorScheme: ColorScheme.fromSwatch().copyWith(primary: Colors.black),
      ),
      home: const My(),
    );
  }
}
class My extends StatefulWidget {
  const My({Key? key}) : super(key: key);

  @override
  State<My> createState() => _MyState();
}

class _MyState extends State<My> {
  final TextEditingController _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextFormField(
              controller: _controller,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter artist name",
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => MyHomePage(
                          artist: _controller.text,
                        )));
              },
              child: const Text("Search"),
            ),
          ],
        ),
      ),
    );
  }
}


class MyHomePage extends StatefulWidget {
  final String artist;
  const MyHomePage({Key? key,required this.artist}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Music App",
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 1,
        ),
        child: StreamBuilder<List<Music>>(
          stream: MusicService().getMusic(widget.artist).asStream(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 200,
                  childAspectRatio: 0.7,
                ),
                itemCount: snapshot.data?.length ?? 0,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () async {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => Song(
                                snapshot: snapshot.data![index],
                            index: index,
                              )));
                    },
                    child: Card(
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      color: Colors.black,
                      margin: const EdgeInsets.all(0),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 30
                            ),
                            child: Image.network(
                              snapshot.data?[index].coverMedium ?? "",
                              fit: BoxFit.cover,
                              height: 100,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Text(
                                snapshot.data?[index].title ?? "",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            } else if (snapshot.hasError) {

              return Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(100, 50),
                  ),
                  onPressed: () {
                    setState(() {
                    });
                  },
                  child: const Text("Retry"),
                ),
              );
            }
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
  }
}
class Song extends StatefulWidget {
  final int index;
  final Music snapshot;
   const Song({Key? key, required this.snapshot , required this.index}) : super(key: key);

  @override
  State<Song> createState() => _SongState();
}

class _SongState extends State<Song> {
  late int index = widget.index;
  late Music snapshot = widget.snapshot;
  final audioPlayer = AudioPlayer();
  bool isPlaying = false;
  final ReceivePort _port = ReceivePort();
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  @override
  void initState() {
    super.initState();
    audioPlayer.onPlayerStateChanged.listen((event) {
      setState(() {
        isPlaying = event == PlayerState.playing;
      });
    });
    audioPlayer.onDurationChanged.listen((event) {
      setState(() {
        duration = event;
      });
    });
    audioPlayer.onPositionChanged.listen((event) {
      setState(() {
        position = event;
      });
    });
    IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {

      setState(() {});
    });

    FlutterDownloader.registerCallback(downloadCallback);
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    super.dispose();
    if (audioPlayer.state == PlayerState.playing) {
      audioPlayer.stop();
    }

  }

  @pragma('vm:entry-point')
  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    final SendPort? send =
    IsolateNameServer.lookupPortByName('downloader_send_port');
    send!.send([id, status, progress]);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Expanded(
              child: Center(
                child: Text(
                  snapshot.title ?? "",
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Center(
                child: Image.network(
                  snapshot.coverMedium ?? "",
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Slider(
                  value: position.inSeconds.toDouble(),
                  max: duration.inSeconds.toDouble(),
                  min: 0  ,
                  onChanged: (value) {
                    audioPlayer.seek(Duration(seconds: value.toInt()));
                  },
                ),
              ),
            ),
            Text(
              "${position.inSeconds} / ${duration.inSeconds} seconds",
              style: const TextStyle(fontSize: 20),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () async {
                    if (isPlaying) {
                      await audioPlayer.pause();
                    } else {
                      await audioPlayer.play(UrlSource( snapshot.preview ?? ""));
                    }
                  },
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 70,
                  ),
                ),
                const SizedBox(
                  width: 50,),
                IconButton(
                  onPressed: () async {
                    await audioPlayer.stop();
                    setState(() {
                      position = Duration.zero;
                    });
                  },
                  icon: const Icon(
                    Icons.stop_circle_outlined,
                    size: 70,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 50,
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                      child: ElevatedButton(
                    onPressed: (){
                      Navigator.of(context).pop();
                      audioPlayer.stop();
                    },
                    child: const Text("back to List"),
                  )
                  ),
                  const SizedBox(
                    width: 20,),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (await Permission.storage
                            .request()
                            .isGranted) {
                          var dir =
                          await getExternalStorageDirectory();
                          await FlutterDownloader.enqueue(
                            url: snapshot.preview!,
                            headers: {
                              "apikey": MusicService.apiKey
                            },
                            fileName: snapshot.title!,
                            savedDir: dir!.path,
                            showNotification: true,
                            saveInPublicStorage: true,
                            openFileFromNotification: false,
                          );
                        } else {
                          await Permission.storage.request();
                        }
                      },
                      child: const Text("Download"),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class MusicService {
  static const apiKey = "000a2e29f4msh10526b4714fea05p101321jsn23d55b48f714";
  static const apiHost = "deezerdevs-deezer.p.rapidapi.com";
  static const apiUrl = "https://$apiHost/search?q=eminem";

  Future<List<Music>> getMusic(
    String? artist,
  ) async {
    var response = await http
        .get(Uri.parse('https://$apiHost/search?q=$artist'), headers: {
      "x-rapidapi-key": apiKey,
      "x-rapidapi-host": apiHost,
    });

    if (response.statusCode == 200) {
      var data = json.decode(response.body)["data"];
      if (kDebugMode) {
        print(data);
      }
      return List.from(data.map((x) => Music.fromJson(x)));
    } else {
      throw Exception("Failed to load music data");
    }
  }
}

class Music {
  int? id;
  String? title;
  String? preview;
  String? coverMedium;

  Music({this.id, this.title, this.preview, this.coverMedium});

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
        id: json["id"],
        title: json["title"],
        preview: json["preview"],
        coverMedium: Map<String, dynamic>.from(json["album"])["cover_medium"]);
  }
}
