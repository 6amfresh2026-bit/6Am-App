import 'package:flutter/material.dart';

import '../privacy_policy/legal_document_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalDocumentScreen(
        title: 'Terms of service',
        pageKey: 'terms',
      );
}
