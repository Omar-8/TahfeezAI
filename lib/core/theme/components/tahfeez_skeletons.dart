import 'package:flutter/material.dart';

import '../app_spacing.dart';
import 'tahfeez_card.dart';
import 'tahfeez_state_views.dart';

/// Content-shaped loading placeholders: what is coming — a list's rows, a
/// grid's cards, a card's lines — pulsing ([TahfeezSkeleton]), so the page
/// keeps its shape as it fills in rather than jumping from a centered
/// loader to content (owner, 2026-11-14). Never scrolling, and clipped:
/// sized to the space they are given.

/// The bars of a line of text, varied from row to row so the placeholder
/// does not read as a grid of identical stripes.
double _width(int i, List<double> widths) => widths[i % widths.length];

/// A list loading: [rows] rows shaped like its items — a leading circle
/// (a number), a title and a line under it, and a short trailing bar.
class TahfeezListSkeleton extends StatelessWidget {
  const TahfeezListSkeleton({
    super.key,
    this.rows = 10,
    this.leading = true,
    this.trailing = true,
    this.padding = const EdgeInsets.all(TahfeezSpacing.md),
  });

  final int rows;
  final bool leading;
  final bool trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        key: const ValueKey('list-skeleton'),
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: TahfeezSkeleton(
          child: Column(
            spacing: TahfeezSpacing.xs,
            children: [
              for (var i = 0; i < rows; i++)
                TahfeezCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TahfeezSpacing.md,
                    vertical: TahfeezSpacing.smPlus,
                  ),
                  child: Row(
                    spacing: TahfeezSpacing.md,
                    children: [
                      if (leading)
                        const SizedBox.square(
                          dimension: 36,
                          child: TahfeezSkeletonBar(height: 36),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: TahfeezSpacing.xs,
                          children: [
                            TahfeezSkeletonBar(
                              widthFactor: _width(i, const [0.55, 0.4, 0.7]),
                            ),
                            TahfeezSkeletonBar(
                              height: 12,
                              widthFactor: _width(i, const [0.3, 0.45, 0.25]),
                            ),
                          ],
                        ),
                      ),
                      if (trailing)
                        const SizedBox(
                          width: 56,
                          child: TahfeezSkeletonBar(height: 20),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A grid of cards loading: [count] cards, each an icon's square, a title
/// and a line — at most [maxExtent] wide, [extent] tall (scaled with the
/// text, as such grids are).
class TahfeezGridSkeleton extends StatelessWidget {
  const TahfeezGridSkeleton({
    super.key,
    this.count = 8,
    this.maxExtent = 200,
    this.extent = 148,
    this.padding = const EdgeInsets.all(TahfeezSpacing.md),
  });

  final int count;
  final double maxExtent;
  final double extent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    return TahfeezSkeleton(
      child: GridView.builder(
        key: const ValueKey('grid-skeleton'),
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: scale.scale(maxExtent),
          mainAxisExtent: scale.scale(extent),
          crossAxisSpacing: TahfeezSpacing.sm,
          mainAxisSpacing: TahfeezSpacing.sm,
        ),
        itemCount: count,
        itemBuilder: (context, i) => TahfeezCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox.square(
                dimension: 40,
                child: TahfeezSkeletonBar(height: 40),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: TahfeezSpacing.xs,
                children: [
                  TahfeezSkeletonBar(
                    widthFactor: _width(i, const [0.7, 0.55, 0.8]),
                  ),
                  const TahfeezSkeletonBar(height: 12, widthFactor: 0.4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card's content loading: a title bar, then [lines] lines of text (the
/// last shorter), with [tall] a taller block first (an ayah's Arabic, a
/// chart).
class TahfeezCardSkeleton extends StatelessWidget {
  const TahfeezCardSkeleton({super.key, this.lines = 3, this.tall = 0});

  final int lines;

  /// A block this tall before the lines (0: none).
  final double tall;

  @override
  Widget build(BuildContext context) {
    return TahfeezSkeleton(
      child: Column(
        key: const ValueKey('card-skeleton'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.sm,
        children: [
          const TahfeezSkeletonBar(height: 20, widthFactor: 0.45),
          if (tall > 0) TahfeezSkeletonBar(height: tall),
          for (var i = 0; i < lines; i++)
            TahfeezSkeletonBar(
              height: 14,
              widthFactor: i == lines - 1
                  ? 0.6
                  : _width(i, const [1, 0.9, 0.95]),
            ),
        ],
      ),
    );
  }
}

/// A page of cards loading: one card per entry of [cards], that many
/// lines in it (a page such as Memorize or Progress).
class TahfeezCardsSkeleton extends StatelessWidget {
  const TahfeezCardsSkeleton({
    super.key,
    this.cards = const [2, 4, 3, 3],
    this.padding = const EdgeInsets.all(TahfeezSpacing.md),
  });

  final List<int> cards;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        key: const ValueKey('cards-skeleton'),
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TahfeezSpacing.md,
          children: [
            for (final lines in cards)
              TahfeezCard(child: TahfeezCardSkeleton(lines: lines)),
          ],
        ),
      ),
    );
  }
}
