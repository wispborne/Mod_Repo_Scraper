import 'package:dart_mappable/dart_mappable.dart';

part 'bundle_meta.mapper.dart';

@MappableClass(ignoreNull: true)
class BundleMeta with BundleMetaMappable {
  final DateTime generatedAt;
  final int totalMods;
  final int totalDetails;
  final int totalAssumedDownloadEntries;
  final int placeholderDetailCount;
  final int? scrapeDurationSeconds;
  final int? modsScraped;
  final int? imagesDownloaded;
  final int? errors;

  BundleMeta({
    required this.generatedAt,
    this.totalMods = 0,
    this.totalDetails = 0,
    this.totalAssumedDownloadEntries = 0,
    this.placeholderDetailCount = 0,
    this.scrapeDurationSeconds,
    this.modsScraped,
    this.imagesDownloaded,
    this.errors,
  });
}
