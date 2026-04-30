import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StudioBackground extends StatelessWidget {
  final Widget child;

  const StudioBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FBFF), Color(0xFFF0F5FD), Color(0xFFE9F0FA)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -120, right: -80, child: _orb(const Color(0x29C6D9F5), 280)),
          Positioned(bottom: -140, left: -90, child: _orb(const Color(0x23FFD1C4), 300)),
          Positioned(top: 180, left: -70, child: _orb(const Color(0x20A7C6F3), 180)),
          child,
        ],
      ),
    );
  }

  Widget _orb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class AnimatedGradientHeader extends StatefulWidget {
  final String title;
  final String subtitle;

  const AnimatedGradientHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  State<AnimatedGradientHeader> createState() => _AnimatedGradientHeaderState();
}

class _AnimatedGradientHeaderState extends State<AnimatedGradientHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment(-1 + t, -1),
              end: Alignment(1, 1 - t),
              colors: const [Color(0xFFFFFFFF), Color(0xFFF2F7FF), Color(0xFFE9F2FF)],
            ),
            border: Border.all(color: const Color(0x99BDD1ED)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A7DA0D6),
                blurRadius: 26,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(widget.subtitle, style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
        );
      },
    );
  }
}

class CountUpText extends StatelessWidget {
  final num value;
  final int durationMs;
  final String prefix;
  final String suffix;
  final int fractionDigits;
  final TextStyle? style;

  const CountUpText({
    super.key,
    required this.value,
    this.durationMs = 900,
    this.prefix = '',
    this.suffix = '',
    this.fractionDigits = 0,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: Duration(milliseconds: durationMs),
      builder: (context, val, _) {
        return Text(
          '$prefix${val.toStringAsFixed(fractionDigits)}$suffix',
          style: style,
        );
      },
    );
  }
}

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const SectionCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x88BBD0EA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final double offsetY;

  const Reveal({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.offsetY = 12,
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : Offset(0, widget.offsetY / 100),
        child: widget.child,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
