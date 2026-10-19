import 'package:flutter/material.dart';

/// Aviso compacto para explicar conexão, conferência e diferenças de valores.
class NoteBox extends StatelessWidget {
  const NoteBox(
    this.text, {
    super.key,
    this.icon = Icons.info_outline,
    this.warning = false,
  });
  final String text;
  final IconData icon;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFF2DC) : const Color(0xFFEAF2ED),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: warning ? const Color(0xFF94631C) : const Color(0xFF276447),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

/// Estado vazio com instrução útil, sem compras fictícias previamente cadastradas.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: Color(0xFFE3F1E8),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 20), child: action),
      ],
    ),
  );
}

/// Mensagens transitórias substituem a anterior para não formar uma fila de erros.
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
}

/// Cabeçalhos compartilham espaçamento, tipografia e ação opcional à direita.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    subtitle!,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
