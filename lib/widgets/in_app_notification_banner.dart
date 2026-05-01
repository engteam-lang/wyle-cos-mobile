import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/notification_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kBg         = Color(0xFF1C1C1E);
const _kBorder     = Color(0xFF2C2C2E);
const _kTeal       = Color(0xFF1B998B);
const _kTealLight  = Color(0xFF26C9B5);
const _kWhite      = Color(0xFFFFFFFF);
const _kTextSec    = Color(0xFFAAAAAA);

const _kAutoDismissMs = 4500;   // ms before auto-slide-out
const _kMaxStack      = 3;      // max banners stacked at once

/// Drop-in widget that listens to [NotificationService.foregroundStream] and
/// slides a premium dark banner down from the top whenever a push notification
/// arrives while the app is in the foreground.
///
/// Usage — wrap the root child in MaterialApp.router builder:
/// ```dart
/// builder: (context, child) {
///   return InAppNotificationOverlay(child: child!);
/// }
/// ```
class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;
  const InAppNotificationOverlay({super.key, required this.child});

  @override
  State<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState
    extends State<InAppNotificationOverlay> {
  StreamSubscription<RemoteMessage>? _sub;
  final List<_BannerEntry> _banners = [];

  @override
  void initState() {
    super.initState();
    _sub = NotificationService.instance.foregroundStream
        .listen(_onMessage);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onMessage(RemoteMessage message) {
    // Buddy chat screen now handles all foreground notifications by rendering
    // them directly in the conversation.  The banner overlay is kept in place
    // for future use (e.g. notifications on non-buddy screens) but is currently
    // a no-op — NotificationService only emits to foregroundStream when
    // buddyIsListening is true, and queues messages otherwise.
    // If you need banners on other screens in future, remove this early return.
  }

  void _dismiss(int id) {
    if (!mounted) return;
    setState(() => _banners.removeWhere((b) => b.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Banners stacked just below the status bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _banners.map((b) => _BannerTile(
                key:     ValueKey(b.id),
                title:   b.title,
                body:    b.body,
                onDismiss: () => _dismiss(b.id),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Internal data ─────────────────────────────────────────────────────────────
class _BannerEntry {
  final int    id;
  final String title;
  final String body;
  const _BannerEntry({required this.id, required this.title, required this.body});
}

// ── Animated banner tile ──────────────────────────────────────────────────────
class _BannerTile extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onDismiss;

  const _BannerTile({
    super.key,
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  @override
  State<_BannerTile> createState() => _BannerTileState();
}

class _BannerTileState extends State<_BannerTile>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;         // slide-in / slide-out
  late final AnimationController _progressCtrl; // shrinking timer bar
  late final Animation<Offset>   _slide;
  late final Animation<double>   _fade;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kAutoDismissMs),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
    _progressCtrl.forward(); // drives the shrinking timer bar 0→1 over 4.5 s

    // Auto-dismiss after _kAutoDismissMs
    _autoTimer = Timer(
      const Duration(milliseconds: _kAutoDismissMs),
      _dismiss,
    );
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _autoTimer?.cancel();
    _progressCtrl.stop();
    if (!mounted) return;
    // Slide back up
    await _ctrl.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeIn,
    );
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: _dismiss,
          // Swipe up to dismiss
          onVerticalDragEnd: (d) {
            if (d.primaryVelocity != null && d.primaryVelocity! < -100) {
              _dismiss();
            }
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            decoration: BoxDecoration(
              color:        _kBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder, width: 1),
              boxShadow: const [
                BoxShadow(
                  color:       Color(0x55000000),
                  blurRadius:  20,
                  spreadRadius: 2,
                  offset:      Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Content row ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Wyle icon badge
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: _kTeal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _kTeal.withOpacity(0.35), width: 1),
                          ),
                          child: Center(
                            child: Text('W',
                              style: GoogleFonts.poppins(
                                color:      _kTealLight,
                                fontSize:   17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        // Title + body
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color:      _kWhite,
                                        fontSize:   13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // "now" timestamp
                                  Text(
                                    _timeLabel(),
                                    style: GoogleFonts.inter(
                                      color:    _kTextSec,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.body.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  widget.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color:    _kTextSec,
                                    fontSize: 12,
                                    height:   1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // X dismiss button
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size:  13,
                              color: _kTextSec,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Progress bar (shrinks left→right over _kAutoDismissMs) ─
                  AnimatedBuilder(
                    animation: _progressCtrl,
                    builder: (_, __) => Container(
                      height: 2,
                      color: _kBorder,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (1.0 - _progressCtrl.value)
                            .clamp(0.0, 1.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_kTeal, _kTealLight],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Returns a human-readable timestamp for the banner (e.g. "now", "1m ago").
  String _timeLabel() {
    final now = DateTime.now();
    final h   = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m   = now.minute.toString().padLeft(2, '0');
    final ap  = now.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }
}
