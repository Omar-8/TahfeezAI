import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../domain/credits.dart';

/// Settings → About: what Tahfeez is, every source it uses with its owner,
/// licence and purpose (tap a link to copy it), and Flutter's licence page
/// — the packages' licences and the sources' notices
/// ([registerCreditLicences]).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String title(CreditGroup g) => switch (g) {
      CreditGroup.quran => l10n.aboutGroupQuran,
      CreditGroup.translations => l10n.aboutGroupTranslations,
      CreditGroup.mushaf => l10n.aboutGroupMushaf,
      CreditGroup.ai => l10n.aboutGroupAi,
      CreditGroup.data => l10n.aboutGroupData,
      CreditGroup.software => l10n.aboutGroupSoftware,
    };
    return Scaffold(
      appBar: TahfeezAppBar(title: Text(l10n.aboutTitle), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(TahfeezSpacing.md),
        children: [
          Text(l10n.appName, style: theme.textTheme.headlineSmall),
          Text(
            l10n.aboutVersion(version),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TahfeezSpacing.sm),
          Text(l10n.aboutIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: TahfeezSpacing.md),
          FilledButton.tonalIcon(
            key: const ValueKey('about-licences'),
            icon: const Icon(Icons.gavel_outlined),
            label: Text(l10n.aboutLicences),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: l10n.appName,
              applicationVersion: version,
            ),
          ),
          // The privacy policy's essentials (docs/PRIVACY_POLICY.md).
          const SizedBox(height: TahfeezSpacing.lg),
          TahfeezSectionHeader(title: l10n.privacyTitle),
          const SizedBox(height: TahfeezSpacing.sm),
          TahfeezCard(
            key: const ValueKey('about-privacy'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: TahfeezSpacing.sm,
              children: [
                for (final (icon, text) in [
                  (Icons.mic_none_rounded, l10n.privacyRecitation),
                  (Icons.phone_android_rounded, l10n.privacyLocal),
                  (Icons.cloud_outlined, l10n.privacyNetwork),
                  (Icons.block_rounded, l10n.privacyNoTracking),
                  (Icons.delete_outline_rounded, l10n.privacyDelete),
                ])
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: TahfeezSpacing.smPlus,
                    children: [
                      Icon(icon, size: 20, color: theme.colorScheme.primary),
                      Expanded(
                        child: Text(text, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          for (final group in CreditGroup.values) ...[
            const SizedBox(height: TahfeezSpacing.lg),
            TahfeezSectionHeader(title: title(group)),
            const SizedBox(height: TahfeezSpacing.sm),
            for (final c in credits.where((c) => c.group == group))
              Padding(
                padding: const EdgeInsets.only(bottom: TahfeezSpacing.sm),
                child: TahfeezCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: TahfeezSpacing.xs,
                    children: [
                      Text(c.name, style: theme.textTheme.titleSmall),
                      Text(
                        arabic ? c.useAr : c.useEn,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '${l10n.aboutBy} ${c.owner}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        '${l10n.aboutLicence} ${c.licence}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (c.citation case final cite?)
                        Text(
                          '${l10n.aboutCite} $cite',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      InkWell(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: c.url));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.aboutCopied)),
                          );
                        },
                        child: Text(
                          c.url,
                          textDirection: TextDirection.ltr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Adds every credited source's notice to Flutter's licence registry, so
/// the standard licence page lists them beside the packages'.
void registerCreditLicences() {
  LicenseRegistry.addLicense(
    () => Stream.fromIterable([
      for (final c in credits)
        LicenseEntryWithLineBreaks(['Tahfeez: ${c.name}'], c.notice),
    ]),
  );
}
