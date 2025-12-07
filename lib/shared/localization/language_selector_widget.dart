import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:longeviva_admin_v1/shared/localization/translation_extension.dart';

import '../utils/colors.dart';
import 'language_bloc.dart';

class LanguageSelector extends StatelessWidget {
  final bool isSmallScreen;

  const LanguageSelector({super.key, required this.isSmallScreen});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LanguageBloc, LanguageState>(
      builder: (context, state) {
        return PopupMenuButton<String>(
          icon: const Icon(Icons.language),
          iconColor: isSmallScreen ? CustomColors.biancoPuro : CustomColors.verdeAbisso,
          tooltip: context.tr('common.change_language'),
          onSelected: (String languageCode) {
            context.read<LanguageBloc>().add(LanguageChanged(languageCode));
          },
          color: CustomColors.biancoPuro,
          itemBuilder: (BuildContext context) {
            return state.supportedLanguages.map((language) {
              return PopupMenuItem<String>(
                value: language.code,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language.name,
                      style: const TextStyle(fontFamily: "Montserrat", fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    if (state.locale.languageCode == language.code)
                      const Icon(Icons.check, color: Colors.green),
                  ],
                ),
              );
            }).toList();
          },
        );
      },
    );
  }
}
