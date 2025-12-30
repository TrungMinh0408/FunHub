import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'fullscreen_video.dart';

class PostMediaCarousel extends StatefulWidget {
  final List<dynamic> media;
  const PostMediaCarousel({super.key, required this.media});

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  final PageController _pageCtrl = PageController();
  VideoPlayerController? _videoController;
  int _index = 0;
  bool _visibleEnough = false;

  @override
  void initState() {
    super.initState();
    _initVideoAtIndex(0);
  }

  Future<void> _initVideoAtIndex(int i) async {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;

    final item = widget.media[i];
    if (item['type'] == 'video') {
      final ctrl = VideoPlayerController.network(item['url']);
      await ctrl.initialize();
      _videoController = ctrl;

      if (_visibleEnough) {
        ctrl.play();
      }

      if (mounted) setState(() {});
    }
  }

  void _showFullScreen(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: item['type'] == 'image'
                  ? InteractiveViewer(
                child: Image.network(item['url'], fit: BoxFit.contain),
              )
                  : FullScreenVideo(url: item['url']),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) return const SizedBox();

    return VisibilityDetector(
      key: Key('post-media-${widget.hashCode}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0.6;
        if (_visibleEnough != visible) {
          _visibleEnough = visible;
          if (_videoController != null) {
            visible ? _videoController!.play() : _videoController!.pause();
          }
        }
      },
      child: Column(
        children: [
          SizedBox(
            height: 320,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.media.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                _initVideoAtIndex(i);
              },
              itemBuilder: (_, i) {
                final item = widget.media[i];

                return GestureDetector(
                  onTap: () => _showFullScreen(item),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item['type'] == 'image'
                        ? Image.network(item['url'], fit: BoxFit.cover)
                        : (_videoController != null &&
                        i == _index &&
                        _videoController!.value.isInitialized)
                        ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                        : Container(
                      color: Colors.black,
                      child: const Icon(
                        Icons.videocam,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.media.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.media.length,
                    (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _index == i ? 24 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _index == i
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }
}