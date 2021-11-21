import 'package:get_it/get_it.dart';
import 'package:shiori/application/bloc.dart';
import 'package:shiori/domain/services/calculator_service.dart';
import 'package:shiori/domain/services/changelog_provider.dart';
import 'package:shiori/domain/services/data_service.dart';
import 'package:shiori/domain/services/device_info_service.dart';
import 'package:shiori/domain/services/game_code_service.dart';
import 'package:shiori/domain/services/genshin_service.dart';
import 'package:shiori/domain/services/locale_service.dart';
import 'package:shiori/domain/services/logging_service.dart';
import 'package:shiori/domain/services/network_service.dart';
import 'package:shiori/domain/services/notification_service.dart';
import 'package:shiori/domain/services/settings_service.dart';
import 'package:shiori/domain/services/telemetry_service.dart';
import 'package:shiori/infrastructure/infrastructure.dart';

final GetIt getIt = GetIt.instance;

class Injection {
  static CalculatorAscMaterialsSessionFormBloc get calculatorAscMaterialsSessionFormBloc {
    return CalculatorAscMaterialsSessionFormBloc();
  }

  static ChangelogBloc get changelogBloc {
    final changelogProvider = getIt<ChangelogProvider>();
    return ChangelogBloc(changelogProvider);
  }

  static ElementsBloc get elementsBloc {
    final genshinService = getIt<GenshinService>();
    return ElementsBloc(genshinService);
  }

  static GameCodesBloc get gameCodesBloc {
    final dataService = getIt<DataService>();
    final telemetryService = getIt<TelemetryService>();
    final gameCodeService = getIt<GameCodeService>();
    final networkService = getIt<NetworkService>();
    return GameCodesBloc(dataService, telemetryService, gameCodeService, networkService);
  }

  static ItemQuantityFormBloc get itemQuantityFormBloc {
    return ItemQuantityFormBloc();
  }

  static CalculatorAscMaterialsOrderBloc getCalculatorAscMaterialsOrderBloc(CalculatorAscMaterialsBloc bloc) {
    final dataService = getIt<DataService>();
    return CalculatorAscMaterialsOrderBloc(dataService, bloc);
  }

  static CalculatorAscMaterialsSessionsOrderBloc getCalculatorAscMaterialsSessionsOrderBloc(CalculatorAscMaterialsSessionsBloc bloc) {
    final dataService = getIt<DataService>();
    return CalculatorAscMaterialsSessionsOrderBloc(dataService, bloc);
  }

  static Future<void> init() async {
    final networkService = NetworkServiceImpl();
    networkService.init();
    getIt.registerSingleton<NetworkService>(networkService);

    final deviceInfoService = DeviceInfoServiceImpl();
    getIt.registerSingleton<DeviceInfoService>(deviceInfoService);
    await deviceInfoService.init();

    final telemetryService = TelemetryServiceImpl(deviceInfoService);
    getIt.registerSingleton<TelemetryService>(telemetryService);
    await telemetryService.initTelemetry();

    final loggingService = LoggingServiceImpl(getIt<TelemetryService>(), deviceInfoService);

    getIt.registerSingleton<LoggingService>(loggingService);
    final settingsService = SettingsServiceImpl(loggingService);
    await settingsService.init();
    getIt.registerSingleton<SettingsService>(settingsService);
    getIt.registerSingleton<LocaleService>(LocaleServiceImpl(getIt<SettingsService>()));
    getIt.registerSingleton<GenshinService>(GenshinServiceImpl(getIt<LocaleService>()));
    getIt.registerSingleton<CalculatorService>(CalculatorServiceImpl(getIt<GenshinService>()));

    final dataService = DataServiceImpl(getIt<GenshinService>(), getIt<CalculatorService>());
    await dataService.init();
    getIt.registerSingleton<DataService>(dataService);

    getIt.registerSingleton<GameCodeService>(GameCodeServiceImpl(getIt<LoggingService>(), getIt<GenshinService>()));

    final notificationService = NotificationServiceImpl(loggingService);
    await notificationService.init();
    getIt.registerSingleton<NotificationService>(notificationService);

    final changelogProvider = ChangelogProviderImpl(loggingService, networkService);
    getIt.registerSingleton<ChangelogProvider>(changelogProvider);
  }
}
