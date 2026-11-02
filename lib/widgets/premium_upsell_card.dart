import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../config/app_brand.dart';
import '../l10n/l10n_scope.dart';

/// Premium pitch shown under storage for free accounts only.
class PremiumUpsellCard extends StatelessWidget {
  const PremiumUpsellCard({super.key, this.onPressed});

  /// Replaces the pricing-page launch. Tests use this.
  final VoidCallback? onPressed;

  Future<void> _openPricing(BuildContext context) async {
    final action = onPressed;
    if (action != null) {
      action();
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final message = context.l10nRead.premiumUpsellOpenFailed;
    try {
      final opened = await launchUrl(
        ApiConfig.pricingUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        messenger?.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final accent = AppBrand.current.palette.accent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final night = isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A);
    final mid = isDark ? const Color(0xFF243044) : const Color(0xFF1E293B);
    final glow = Color.lerp(night, accent, isDark ? 0.42 : 0.5)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accent.withValues(alpha: isDark ? 0.5 : 0.28),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [night, mid, glow],
            stops: const [0.0, 0.58, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: night.withValues(alpha: isDark ? 0.0 : 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -36,
              top: -48,
              child: IgnorePointer(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.55),
                        accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white.withValues(alpha: 0.12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s.premiumUpsellBadge,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.premiumUpsellTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.premiumUpsellBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _benefit(
                    context,
                    Icons.cloud_outlined,
                    s.premiumUpsellStorageBenefit,
                    accent,
                  ),
                  _benefit(
                    context,
                    Icons.block,
                    s.premiumUpsellAdsBenefit,
                    accent,
                  ),
                  _benefit(
                    context,
                    Icons.photo_album_outlined,
                    s.premiumUpsellAlbumsBenefit,
                    accent,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.premiumUpsellPriceAmount,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    s.premiumUpsellPriceCaption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.premiumUpsellPriceNote,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const Key('premium-upsell-cta'),
                    onPressed: () => _openPricing(context),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(s.premiumUpsellCta),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefit(
    BuildContext context,
    IconData icon,
    String label,
    Color accent,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
