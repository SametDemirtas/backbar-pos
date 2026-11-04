import 'package:flutter/material.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

import 'firebase_options.dart';
import 'src/menu_list_page.dart';

void main() {
  runApp(const ManagerApp());
}

class ManagerApp extends StatelessWidget {
  const ManagerApp({super.key, this.venue = VenueConfig.demo});

  final VenueConfig venue;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backbar Manager',
      debugShowCheckedModeBanner: false,
      theme: PosTheme.daylight,
      home: AppBootstrap(
        productionOptions: () => DefaultFirebaseOptions.currentPlatform,
        builder: (context, boot) => _ManagerRoot(venue: venue),
      ),
    );
  }
}

class _ManagerRoot extends StatefulWidget {
  const _ManagerRoot({required this.venue});

  final VenueConfig venue;

  @override
  State<_ManagerRoot> createState() => _ManagerRootState();
}

class _ManagerRootState extends State<_ManagerRoot> {
  late final _menu = FirestoreMenuRepository(venueId: widget.venue.venueId);

  @override
  Widget build(BuildContext context) {
    return MenuListPage(repository: _menu, venue: widget.venue);
  }
}
