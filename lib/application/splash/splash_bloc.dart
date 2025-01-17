import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/domain/enums/enums.dart';
import 'package:shiori/domain/models/models.dart';
import 'package:shiori/domain/services/device_info_service.dart';
import 'package:shiori/domain/services/locale_service.dart';
import 'package:shiori/domain/services/resources_service.dart';
import 'package:shiori/domain/services/settings_service.dart';
import 'package:shiori/domain/services/telemetry_service.dart';

part 'splash_bloc.freezed.dart';
part 'splash_event.dart';
part 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  final ResourceService _resourceService;
  final SettingsService _settingsService;
  final DeviceInfoService _deviceInfoService;
  final TelemetryService _telemetryService;
  final LanguageModel _language;

  StreamSubscription? _downloadStream;

  SplashBloc(
    this._resourceService,
    this._settingsService,
    this._deviceInfoService,
    this._telemetryService,
    LocaleService localeService,
  )   : _language = localeService.getLocaleWithoutLang(),
        super(const SplashState.loading());

  @override
  Stream<SplashState> mapEventToState(SplashEvent event) async* {
    if (event is _Init) {
      final noResourcesHasBeenDownloaded = _settingsService.noResourcesHasBeenDownloaded;
      //This is just to trigger a change in the ui
      if (event.retry) {
        yield SplashState.loaded(
          updateResultType: AppResourceUpdateResultType.retrying,
          language: _language,
          noResourcesHasBeenDownloaded: noResourcesHasBeenDownloaded,
        );
        await Future.delayed(const Duration(seconds: 1));
      }

      final result = await _resourceService.checkForUpdates(_deviceInfoService.version, _settingsService.resourceVersion);
      final unknownErrorOnFirstInstall = result.type == AppResourceUpdateResultType.unknownError && _settingsService.noResourcesHasBeenDownloaded;
      final resultType = unknownErrorOnFirstInstall ? AppResourceUpdateResultType.unknownErrorOnFirstInstall : result.type;
      await _telemetryService.trackCheckForResourceUpdates(resultType);
      yield SplashState.loaded(
        updateResultType: resultType,
        language: _language,
        result: result,
        noResourcesHasBeenDownloaded: noResourcesHasBeenDownloaded,
      );
      return;
    }

    if (event is _ApplyUpdate) {
      assert(state is _LoadedState, 'The current state should be loaded');
      final currentState = state as _LoadedState;
      assert(currentState.result != null, 'The update result must not be null');
      yield currentState.copyWith(updateResultType: AppResourceUpdateResultType.updating);

      //the stream is required to avoid blocking the bloc
      final result = currentState.result!;
      final downloadStream = _resourceService
          .downloadAndApplyUpdates(
            result.resourceVersion,
            result.jsonFileKeyName,
            keyNames: result.keyNames,
            onProgress: (value) => add(SplashEvent.progressChanged(progress: value)),
          )
          .asStream();

      await _downloadStream?.cancel();
      _downloadStream = downloadStream.listen(
        (applied) => add(SplashEvent.updateCompleted(applied: applied, resourceVersion: result.resourceVersion)),
      );
    }

    if (event is _ProgressChanged) {
      assert(state is _LoadedState, 'The current state should be loaded');
      if (event.progress < 0) {
        throw Exception('Invalid progress value');
      }

      final currentState = state as _LoadedState;
      if (event.progress >= 100) {
        yield currentState.copyWith(progress: 100);
        return;
      }

      final diff = (event.progress - currentState.progress).abs();
      if (diff < 1) {
        return;
      }
      yield currentState.copyWith(progress: event.progress);
    }

    if (event is _UpdateCompleted) {
      final appliedResult = event.applied
          ? AppResourceUpdateResultType.updated
          : _settingsService.noResourcesHasBeenDownloaded
              ? AppResourceUpdateResultType.unknownErrorOnFirstInstall
              : AppResourceUpdateResultType.unknownError;
      await _telemetryService.trackResourceUpdateCompleted(event.applied, event.resourceVersion);
      yield SplashState.loaded(
        updateResultType: appliedResult,
        language: _language,
        progress: 100,
        noResourcesHasBeenDownloaded: _settingsService.noResourcesHasBeenDownloaded,
      );
    }
  }

  @override
  Future<void> close() async {
    await _downloadStream?.cancel();
    return super.close();
  }
}
