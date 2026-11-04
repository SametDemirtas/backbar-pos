import 'package:flutter/material.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

import 'firebase_options.dart';
import 'src/pos_home_page.dart';

void main() {
  runApp(const PosApp());
}

class PosApp extends StatelessWidget {
  const PosApp({super.key, this.venue = VenueConfig.demo});

  final VenueConfig venue;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backbar POS',
      debugShowCheckedModeBanner: false,
      theme: PosTheme.backbar,
      home: AppBootstrap(
        productionOptions: () => DefaultFirebaseOptions.currentPlatform,
        builder: (context, boot) => _TillRoot(venue: venue, boot: boot),
      ),
    );
  }
}

class _TillRoot extends StatefulWidget {
  const _TillRoot({required this.venue, required this.boot});

  final VenueConfig venue;
  final BootResult boot;

  @override
  State<_TillRoot> createState() => _TillRootState();
}

class _TillRootState extends State<_TillRoot> {
  late final _menu = FirestoreMenuRepository(venueId: widget.venue.venueId);
  late final _orders = FirestoreOrderRepository(venueId: widget.venue.venueId);

  @override
  Widget build(BuildContext context) {
    return PosHomePage(
      menuRepository: _menu,
      orderRepository: _orders,
      venue: widget.venue,
      staffUid: widget.boot.staffUid,
    );
  }
}
