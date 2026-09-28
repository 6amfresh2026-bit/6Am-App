import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalDocumentScreen(
        title: 'Privacy policy',
        pageKey: 'privacy',
      );
}
