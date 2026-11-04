import 'package:flutter/foundation.dart';

@immutable
class VenueConfig {
  const VenueConfig({
    required this.venueId,
    required this.displayName,
    required this.currencySymbol,
    required this.tillLabel,
    this.stationLabel,
  }) : assert(
         tillLabel.length > 0 && tillLabel.length <= 40,
         'The rules refuse an order whose till label is empty or over 40',
       );

  final String venueId;
  final String displayName;

  final String currencySymbol;

  final String tillLabel;

  final String? stationLabel;

  static const VenueConfig demo = VenueConfig(
    venueId: 'copper-kettle',
    displayName: 'The Copper Kettle',
    currencySymbol: '£',
    tillLabel: 'TILL 1',
    stationLabel: 'Main bar',
  );
}
