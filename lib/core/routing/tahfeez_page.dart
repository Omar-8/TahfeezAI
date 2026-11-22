import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tahfeez_motion.dart';

/// A screen opened over another (the side menu's — Qibla, Settings, About,
/// Bookmarks): fading in as it slides a little from the side it is read
/// from; gone at once as it closes — no animation back (owner, 2026-11-20:
/// neither the fade nor the slide back felt smooth). At once with
/// animations off.
CustomTransitionPage<void> tahfeezPage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: TahfeezMotionDuration.slow,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondary, child) {
        if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
          return child;
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: TahfeezMotionCurves.standard,
        );
        final rtl = Directionality.of(context) == TextDirection.rtl;
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: Offset(rtl ? -0.08 : 0.08, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
