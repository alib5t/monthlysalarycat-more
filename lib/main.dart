
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1100, 750),
      minimumSize: Size(500, 350),
      center: true,
      backgroundColor: Colors.white,
      title: '月薪貓更多',
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(
      windowOptions,
      () async {
        await windowManager.setTitleBarStyle(
          TitleBarStyle.normal,
        );

        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(const VideoApp());
}

class VideoApp extends StatelessWidget {
  const VideoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VideoScreen(),
    );
  }
}

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final Player videoPlayer;
  late final Player musicPlayer;
  late final VideoController videoController;

  bool ready = false;
  String? error;

  double videoRatio = 16 / 9;

  @override
  void initState() {
    super.initState();

    videoPlayer = Player();
    musicPlayer = Player();
    videoController = VideoController(videoPlayer);

    videoPlayer.stream.width.listen((_) => updateRatio());
    videoPlayer.stream.height.listen((_) => updateRatio());

    startMedia();
  }

  void updateRatio() {
    final w = videoPlayer.state.width;
    final h = videoPlayer.state.height;

    if (w != null && h != null && w > 0 && h > 0) {
      if (mounted) {
        setState(() {
          videoRatio = w / h;
        });
      }
    }
  }

  Future<File> copyAsset(String name) async {
    final data = await rootBundle.load(name);

    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    final directory = await getTemporaryDirectory();

    final file = File(
      '${directory.path}/${name.split('/').last}',
    );

    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  Future<void> startMedia() async {
    try {
      final video = await copyAsset('assets/video.mp4');
      final music = await copyAsset('assets/music.mp3');

      await videoPlayer.setPlaylistMode(PlaylistMode.loop);
      await musicPlayer.setPlaylistMode(PlaylistMode.loop);

      await videoPlayer.open(
        Media(video.path),
        play: true,
      );

      await musicPlayer.open(
        Media(music.path),
        play: true,
      );

      updateRatio();

      if (mounted) {
        setState(() => ready = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Medya açılamadı: $e';
        });
      }
    }
  }

  Future<void> toggleFullScreen() async {
    if (!Platform.isWindows) return;

    final current = await windowManager.isFullScreen();

    await windowManager.setFullScreen(!current);
  }

  KeyEventResult handleKey(
    FocusNode node,
    KeyEvent event,
  ) {
    if (Platform.isWindows &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.f11) {
      toggleFullScreen();

      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    videoPlayer.dispose();
    musicPlayer.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: handleKey,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final maxHeight = constraints.maxHeight;

              final width = (maxWidth < maxHeight * videoRatio)
                  ? maxWidth
                  : maxHeight * videoRatio;

              final height = width / videoRatio;

              return Center(
                child: error != null
                    ? Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.black,
                        ),
                      )
                    : !ready
                        ? const SizedBox.shrink()
                        : SizedBox(
                            width: width,
                            height: height,
                            child: Video(
                              controller: videoController,
                              fit: BoxFit.contain,
                              controls: NoVideoControls,
                            ),
                          ),
              );
            },
          ),
        ),
      ),
    );
  }
}
