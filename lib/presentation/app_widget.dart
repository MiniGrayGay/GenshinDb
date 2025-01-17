import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shiori/application/bloc.dart';
import 'package:shiori/generated/l10n.dart';
import 'package:shiori/presentation/main_tab_page.dart';
import 'package:shiori/presentation/shared/extensions/app_theme_type_extensions.dart';
import 'package:shiori/presentation/splash/splash_page.dart';

class AppWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final delegates = <LocalizationsDelegate>[
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
    return BlocBuilder<MainBloc, MainState>(
      builder: (ctx, state) => state.map<Widget>(
        loading: (s) => SplashPage(language: s.language, delegates: delegates),
        loaded: (s) {
          final locale = Locale(s.language.code, s.language.countryCode);
          return MaterialApp(
            title: s.appTitle,
            theme: s.accentColor.getThemeData(s.theme, s.useDarkAmoledTheme),
            home: MainTabPage(showChangelog: s.versionChanged, updateResult: s.updateResult),
            themeMode: ThemeMode.dark,
            //Without this, the lang won't be reloaded
            locale: locale,
            localizationsDelegates: delegates,
            supportedLocales: S.delegate.supportedLocales,
            scrollBehavior: MyCustomScrollBehavior(),
          );
        },
      ),
    );
  }
}

// Since 2.5 the scroll behavior changed on desktop,
// this keeps the old one working
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}
