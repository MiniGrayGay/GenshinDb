import 'package:shiori/domain/app_constants.dart';
import 'package:shiori/domain/enums/enums.dart';
import 'package:shiori/domain/models/models.dart';
import 'package:shiori/domain/services/file/file_infrastructure.dart';
import 'package:shiori/domain/services/genshin_service.dart';
import 'package:shiori/domain/services/locale_service.dart';
import 'package:shiori/domain/services/resources_service.dart';
import 'package:shiori/infrastructure/file/file_infrastructure.dart';

class GenshinServiceImpl implements GenshinService {
  final ResourceService _resourceService;
  final TranslationFileService _translations;

  late final ArtifactFileService _artifacts;
  late final BannerHistoryFileService _bannerHistory;
  late final CharacterFileService _characters;
  late final ElementFileService _elements;
  late final FurnitureFileService _furniture;
  late final GadgetFileService _gadgets;
  late final MaterialFileService _materials;
  late final MonsterFileService _monsters;
  late final WeaponFileService _weapons;

  @override
  ArtifactFileService get artifacts => _artifacts;

  @override
  BannerHistoryFileService get bannerHistory => _bannerHistory;

  @override
  CharacterFileService get characters => _characters;

  @override
  ElementFileService get elements => _elements;

  @override
  FurnitureFileService get furniture => _furniture;

  @override
  GadgetFileService get gadgets => _gadgets;

  @override
  MaterialFileService get materials => _materials;

  @override
  MonsterFileService get monsters => _monsters;

  @override
  WeaponFileService get weapons => _weapons;

  @override
  TranslationFileService get translations => _translations;

  GenshinServiceImpl(this._resourceService, LocaleService localeService) : _translations = TranslationFileServiceImpl() {
    _artifacts = ArtifactFileServiceImpl(_resourceService, _translations);
    _elements = ElementFileServiceImpl(_translations);
    _furniture = FurnitureFileServiceImpl();
    _gadgets = GadgetFileServiceImpl();
    _materials = MaterialFileServiceImpl(_resourceService, _translations);
    _monsters = MonsterFileServiceImpl(_resourceService, _translations);
    _weapons = WeaponFileServiceImpl(_resourceService, _materials, _translations);
    _characters = CharacterFileServiceImpl(_resourceService, localeService, _artifacts, _materials, _weapons, _translations);
    _bannerHistory = BannerHistoryFileServiceImpl(_resourceService, _characters, _weapons);
  }

  @override
  Future<void> init(AppLanguageType languageType) async {
    await Future.wait([
      _artifacts.init(_resourceService.getJsonFilePath(AppJsonFileType.artifacts)),
      _bannerHistory.init(_resourceService.getJsonFilePath(AppJsonFileType.bannerHistory)),
      _characters.init(_resourceService.getJsonFilePath(AppJsonFileType.characters)),
      _elements.init(_resourceService.getJsonFilePath(AppJsonFileType.elements)),
      _furniture.init(_resourceService.getJsonFilePath(AppJsonFileType.furniture)),
      _gadgets.init(_resourceService.getJsonFilePath(AppJsonFileType.gadgets)),
      _materials.init(_resourceService.getJsonFilePath(AppJsonFileType.materials)),
      _monsters.init(_resourceService.getJsonFilePath(AppJsonFileType.monsters)),
      _weapons.init(_resourceService.getJsonFilePath(AppJsonFileType.weapons)),
      _translations.initTranslations(languageType, _resourceService.getJsonFilePath(AppJsonFileType.translations, language: languageType))
    ]);
  }

  @override
  int getServerDay(AppServerResetTimeType type) {
    return getServerDate(type).weekday;
  }

  @override
  DateTime getServerDate(AppServerResetTimeType type) {
    final now = DateTime.now();
    final nowUtc = now.toUtc();
    DateTime server;
    // According to this page, the server reset happens at 4 am
    // https://game8.co/games/Genshin-Impact/archives/301599
    switch (type) {
      case AppServerResetTimeType.northAmerica:
        server = nowUtc.subtract(const Duration(hours: 5));
        break;
      case AppServerResetTimeType.europe:
        server = nowUtc.add(const Duration(hours: 1));
        break;
      case AppServerResetTimeType.asia:
        server = nowUtc.add(const Duration(hours: 8));
        break;
      default:
        throw Exception('Invalid server reset type');
    }

    if (server.hour >= serverResetHour) {
      return server;
    }

    return server.subtract(const Duration(days: 1));
  }

  @override
  Duration getDurationUntilServerResetDate(AppServerResetTimeType type) {
    final serverDate = getServerDate(type);
    //Here the utc part is important, otherwise the difference will be calculated using the local time
    final serverResetDate = DateTime.utc(serverDate.year, serverDate.month, serverDate.day, serverResetHour);
    final dateToUse = serverDate.isBefore(serverResetDate) ? serverDate : serverDate.subtract(const Duration(days: 1));
    return serverResetDate.difference(dateToUse);
  }

  @override
  DateTime getNextDateForWeeklyBoss(AppServerResetTimeType type) {
    final durationUntilServerReset = getDurationUntilServerResetDate(type);
    var finalDate = DateTime.now().add(durationUntilServerReset);

    while (finalDate.weekday != DateTime.monday) {
      finalDate = finalDate.add(const Duration(days: 1));
    }

    return finalDate;
  }

  @override
  List<String> getUpcomingKeys() => characters.getUpcomingCharactersKeys() + weapons.getUpcomingWeaponsKeys();

  @override
  String getItemImageFromNotificationType(
    String itemKey,
    AppNotificationType notificationType, {
    AppNotificationItemType? notificationItemType,
  }) {
    switch (notificationType) {
      case AppNotificationType.resin:
      case AppNotificationType.expedition:
      case AppNotificationType.realmCurrency:
        final material = materials.getMaterial(itemKey);
        return _resourceService.getMaterialImagePath(material.image, material.type);
      case AppNotificationType.furniture:
        final furniture = this.furniture.getFurniture(itemKey);
        return _resourceService.getFurnitureImagePath(furniture.image);
      case AppNotificationType.gadget:
        final gadget = gadgets.getGadget(itemKey);
        return _resourceService.getGadgetImagePath(gadget.image);
      case AppNotificationType.farmingArtifacts:
        final artifact = artifacts.getArtifact(itemKey);
        return _resourceService.getArtifactImagePath(artifact.image);
      case AppNotificationType.farmingMaterials:
        final material = materials.getMaterial(itemKey);
        return _resourceService.getMaterialImagePath(material.image, material.type);
      case AppNotificationType.weeklyBoss:
        final monster = monsters.getMonster(itemKey);
        return _resourceService.getMonsterImagePath(monster.image);
      case AppNotificationType.custom:
      case AppNotificationType.dailyCheckIn:
        return getItemImageFromNotificationItemType(itemKey, notificationItemType!);
      default:
        throw Exception('The provided notification type = $notificationType is not valid');
    }
  }

  @override
  String getItemImageFromNotificationItemType(String itemKey, AppNotificationItemType notificationItemType) {
    switch (notificationItemType) {
      case AppNotificationItemType.character:
        final character = characters.getCharacter(itemKey);
        return _resourceService.getCharacterImagePath(character.image);
      case AppNotificationItemType.weapon:
        final weapon = weapons.getWeapon(itemKey);
        return _resourceService.getWeaponImagePath(weapon.image, weapon.type);
      case AppNotificationItemType.artifact:
        final artifact = artifacts.getArtifact(itemKey);
        return _resourceService.getArtifactImagePath(artifact.image);
      case AppNotificationItemType.monster:
        final monster = monsters.getMonster(itemKey);
        return _resourceService.getMonsterImagePath(monster.image);
      case AppNotificationItemType.material:
        final material = materials.getMaterial(itemKey);
        return _resourceService.getMaterialImagePath(material.image, material.type);
      default:
        throw Exception('The provided notification item type = $notificationItemType');
    }
  }

  @override
  List<ChartTopItemModel> getTopCharts(ChartType type) {
    final fiveStars = [
      ChartType.topFiveStarCharacterMostReruns,
      ChartType.topFiveStarCharacterLeastReruns,
      ChartType.topFiveStarWeaponMostReruns,
      ChartType.topFiveStarWeaponLeastReruns,
    ];
    final stars = fiveStars.contains(type) ? 5 : 4;

    final mostRerunsTypes = [
      ChartType.topFiveStarCharacterMostReruns,
      ChartType.topFourStarCharacterMostReruns,
      ChartType.topFiveStarWeaponMostReruns,
      ChartType.topFourStarWeaponMostReruns,
    ];
    final mostReruns = mostRerunsTypes.contains(type);

    switch (type) {
      case ChartType.topFiveStarCharacterMostReruns:
      case ChartType.topFourStarCharacterMostReruns:
      case ChartType.topFiveStarCharacterLeastReruns:
      case ChartType.topFourStarCharacterLeastReruns:
        final characters = this.characters.getItemCommonWithNameByRarity(stars);
        return bannerHistory.getTopCharts(mostReruns, type, BannerHistoryItemType.character, characters);
      case ChartType.topFiveStarWeaponMostReruns:
      case ChartType.topFourStarWeaponMostReruns:
      case ChartType.topFiveStarWeaponLeastReruns:
      case ChartType.topFourStarWeaponLeastReruns:
        final weapons = this.weapons.getItemCommonWithNameByRarity(stars);
        return bannerHistory.getTopCharts(mostReruns, type, BannerHistoryItemType.weapon, weapons);
      default:
        throw Exception('Type = $type is not valid in the getTopCharts method');
    }
  }

  @override
  List<ChartAscensionStatModel> getItemAscensionStatsForCharts(ItemType itemType) {
    if (itemType != ItemType.character && itemType != ItemType.weapon) {
      throw Exception('ItemType = $itemType is not Not supported');
    }

    final stats = itemType == ItemType.character ? getCharacterPossibleAscensionStats() : getWeaponPossibleAscensionStats();
    return stats.map(
      (stat) {
        final count = itemType == ItemType.character ? characters.countByStatType(stat) : weapons.countByStatType(stat);
        return ChartAscensionStatModel(type: stat, itemType: itemType, quantity: count);
      },
    ).toList()
      ..sort((x, y) => y.quantity.compareTo(x.quantity));
  }

  @override
  List<ItemCommonWithName> getItemsAscensionStats(StatType statType, ItemType itemType) {
    final items = <ItemCommonWithName>[];
    switch (itemType) {
      case ItemType.character:
        items.addAll(characters.getItemCommonWithNameByStatType(statType));
        break;
      case ItemType.weapon:
        items.addAll(weapons.getItemCommonWithNameByStatType(statType));
        break;
      default:
        throw Exception('Invalid itemType = $itemType');
    }
    return items..sort((x, y) => x.name.compareTo(y.name));
  }
}
