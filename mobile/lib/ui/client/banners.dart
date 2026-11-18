import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/config.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Club banners under the greeting on Home: a swipeable row of covers; a tap opens [BannerDetailScreen].
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, required this.banners});
  final List<PromoBanner> banners;

  static const height = 176.0;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(PromoBanner banner) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BannerDetailScreen(banner: banner)));
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    // Pages are a gap wider than the list content, so swiping shows a gap between cards while each card
    // stays aligned with the cards below.
    const gap = 12.0;
    return Column(
      key: const Key('home-banners'),
      children: [
        LayoutBuilder(
          builder: (context, c) => SizedBox(
            height: BannerCarousel.height,
            child: OverflowBox(
              minWidth: c.maxWidth + gap,
              maxWidth: c.maxWidth + gap,
              child: PageView.builder(
                controller: _controller,
                itemCount: banners.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: gap / 2),
                  child: _BannerCard(banner: banners[i], onTap: () => _open(banners[i])),
                ),
              ),
            ),
          ),
        ),
        if (banners.length > 1) ...[const SizedBox(height: 10), _Dots(count: banners.length, index: _page)],
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.onTap});
  final PromoBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final radius = BorderRadius.circular(Brand.radiusHero);
    return Semantics(
      button: true,
      label: banner.title,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Cover(url: banner.coverUrl),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.25, 1],
                  colors: [Color(0x00000000), Color(0xB3000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (banner.hasVideo)
                    Align(
                      alignment: Alignment.topRight,
                      child: _Chip(icon: Icons.play_arrow_rounded, label: t.bannerVideo),
                    ),
                  const Spacer(),
                  Text(
                    banner.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      height: 1.15,
                      shadows: [Shadow(color: Color(0x66000000), blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        t.bannerDetails,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white.withValues(alpha: 0.85)),
                    ],
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, borderRadius: radius),
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: Brand.glassStroke),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner cover; without a photo (or if it fails to load) a brand gradient.
class _Cover extends StatelessWidget {
  const _Cover({required this.url});
  final String? url;

  static const _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Brand.accentDark, Brand.glowBlue, Color(0xFF14102E)],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => url == null
      ? _fallback
      : Image.network(
          AppConfig.resolve(url!),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback,
          frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : _fallback,
        );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count, index;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == index ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == index ? Brand.accent : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
    ],
  );
}

/// Banner opened from Home: photos and videos to swipe through, then the title and the text.
class BannerDetailScreen extends StatefulWidget {
  const BannerDetailScreen({super.key, required this.banner});
  final PromoBanner banner;

  @override
  State<BannerDetailScreen> createState() => _BannerDetailScreenState();
}

class _BannerDetailScreenState extends State<BannerDetailScreen> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final b = widget.banner;
    final media = b.media;
    return Scaffold(
      backgroundColor: Brand.background,
      body: GlassBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            key: const Key('banner-detail'),
            padding: EdgeInsets.fromLTRB(
              Brand.sidePadding,
              8,
              Brand.sidePadding,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              Row(
                children: [
                  GlassCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    iconSize: 18,
                    tooltip: t.back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (media.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(Brand.radiusHero),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      children: [
                        PageView.builder(
                          itemCount: media.length,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (_, i) => media[i].kind == BannerMediaKind.video
                              ? _BannerVideo(url: AppConfig.resolve(media[i].url))
                              : ColoredBox(
                                  color: Colors.black,
                                  child: Image.network(
                                    AppConfig.resolve(media[i].url),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => _Cover._fallback,
                                  ),
                                ),
                        ),
                        if (media.length > 1)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: _Chip(icon: Icons.photo_library_outlined, label: '${_page + 1}/${media.length}'),
                          ),
                      ],
                    ),
                  ),
                ),
                if (media.length > 1) ...[const SizedBox(height: 12), _Dots(count: media.length, index: _page)],
                const SizedBox(height: 20),
              ],
              Text(
                b.title,
                style: const TextStyle(
                  color: Brand.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              if (b.description != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  b.description!,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16, height: 1.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Video page of the gallery: the first frame with a play button; tap plays or pauses. The controller lives only
/// while the page is shown, so swiping away stops the video.
class _BannerVideo extends StatefulWidget {
  const _BannerVideo({required this.url});
  final String url;

  @override
  State<_BannerVideo> createState() => _BannerVideoState();
}

class _BannerVideoState extends State<_BannerVideo> {
  late final VideoPlayerController _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then(
      (_) {
        if (mounted) setState(() {});
      },
      onError: (Object _) {
        if (mounted) setState(() => _failed = true);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final v = _controller.value;
    if (!v.isInitialized) return;
    HapticFeedback.selectionClick();
    if (v.isPlaying) {
      _controller.pause();
    } else {
      if (v.position >= v.duration) _controller.seekTo(Duration.zero);
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (_failed) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_outlined, color: Brand.textTertiary, size: 32),
              const SizedBox(height: 8),
              Text(t.bannerVideoError, style: TextStyle(color: Brand.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _controller,
        builder: (context, v, _) {
          if (!v.isInitialized) {
            return const Center(child: CircularProgressIndicator(color: Brand.accent, strokeWidth: 2.5));
          }
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: Stack(
              children: [
                Center(
                  child: AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(_controller)),
                ),
                if (!v.isPlaying)
                  Center(
                    child: Semantics(
                      button: true,
                      label: t.bannerVideo,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.45),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    padding: const EdgeInsets.only(top: 12),
                    colors: VideoProgressColors(
                      playedColor: Brand.accent,
                      bufferedColor: Colors.white.withValues(alpha: 0.3),
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
