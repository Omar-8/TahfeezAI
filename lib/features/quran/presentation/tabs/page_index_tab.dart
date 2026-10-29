import 'package:flutter/material.dart';

import '../../../../core/ui/bar_space.dart';
import '../../../../core/localization/generated/app_localizations.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../quran/domain/models/quran_location.dart';
import '../../../../quran/quran_providers.dart';
import '../../application/quran_index_providers.dart';
import '../../../../quran/presentation/quran_unavailable_view.dart';

/// The Page navigator tab: jump directly to a Mushaf page number
/// (`docs/reference/04_READER_SPEC.md` §4's Page navigator). Rendered as a
/// validated "go to page" entry rather than one row per page (a Mushaf
/// commonly has 600+ pages) — a Tahfeez-owned, more utility-appropriate
/// take on the same "jump to any page" capability.
class PageIndexTab extends ConsumerStatefulWidget {
  const PageIndexTab({super.key, required this.onSelect});

  final ValueChanged<QuranLocation> onSelect;

  @override
  ConsumerState<PageIndexTab> createState() => _PageIndexTabState();
}

class _PageIndexTabState extends ConsumerState<PageIndexTab> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _go(int mushafId) async {
    final pageNumber = int.tryParse(_controller.text);
    if (pageNumber == null) {
      setState(() => _error = AppLocalizations.of(context).quranEnterPage);
      return;
    }
    final repository = ref.read(quranRepositoryProvider);
    final valid = await repository.isValidPage(
      mushafId: mushafId,
      pageNumber: pageNumber,
    );
    if (!valid) {
      setState(() => _error = AppLocalizations.of(context).quranPageOutOfRange);
      return;
    }
    setState(() => _error = null);
    widget.onSelect(QuranLocation.page(mushafId, pageNumber));
  }

  @override
  Widget build(BuildContext context) {
    final mushaf = ref.watch(defaultMushafProvider);

    return Padding(
      padding: withBarSpace(context, const EdgeInsets.all(TahfeezSpacing.md)),
      child: mushaf.when(
        data: (mushaf) {
          if (mushaf == null) {
            return const QuranUnavailableView();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TahfeezSpacing.md,
            children: [
              Text(
                AppLocalizations.of(context).quranMushafPages(mushaf.pageCount),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).quranGoToPage,
                  errorText: _error,
                ),
                onSubmitted: (_) => _go(mushaf.id),
              ),
              FilledButton(
                onPressed: () => _go(mushaf.id),
                child: Text(AppLocalizations.of(context).quranGo),
              ),
            ],
          );
        },
        loading: () => const TahfeezLoadingView(),
        error: (_, _) => const QuranUnavailableView(),
      ),
    );
  }
}
