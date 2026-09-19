import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../quran/domain/models/quran_location.dart';
import '../../../../quran/quran_providers.dart';
import '../../application/quran_index_providers.dart';

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
      setState(() => _error = 'Enter a page number.');
      return;
    }
    final repository = ref.read(quranRepositoryProvider);
    final valid = await repository.isValidPage(
      mushafId: mushafId,
      pageNumber: pageNumber,
    );
    if (!valid) {
      setState(() => _error = 'That page number is out of range.');
      return;
    }
    setState(() => _error = null);
    widget.onSelect(QuranLocation.page(mushafId, pageNumber));
  }

  @override
  Widget build(BuildContext context) {
    final mushaf = ref.watch(defaultMushafProvider);

    return Padding(
      padding: const EdgeInsets.all(TahfeezSpacing.md),
      child: mushaf.when(
        data: (mushaf) {
          if (mushaf == null) {
            return const TahfeezEmptyView(
              icon: Icons.menu_book_outlined,
              message: 'This will appear automatically once a Quran dataset is added to the app.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TahfeezSpacing.md,
            children: [
              Text(
                'This Mushaf has ${mushaf.pageCount} pages.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Go to page',
                  errorText: _error,
                ),
                onSubmitted: (_) => _go(mushaf.id),
              ),
              FilledButton(
                onPressed: () => _go(mushaf.id),
                child: const Text('Go'),
              ),
            ],
          );
        },
        loading: () => const TahfeezLoadingView(),
        error: (_, _) => const TahfeezEmptyView(
          icon: Icons.menu_book_outlined,
          message: 'This will appear automatically once a Quran dataset is added to the app.',
        ),
      ),
    );
  }
}
