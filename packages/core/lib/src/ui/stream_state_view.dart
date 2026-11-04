import 'package:flutter/material.dart';

import '../app/failure_text.dart';
import 'state_message.dart';

class StreamStateView<T> extends StatelessWidget {
  const StreamStateView({
    super.key,
    required this.stream,
    required this.builder,
    required this.emptyTitle,
    this.emptyDetail,
    required this.errorTitle,
  });

  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;

  final String emptyTitle;
  final String? emptyDetail;
  final String errorTitle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StateMessage(
            title: errorTitle,
            detail: describeFailure(snapshot.error!),
            tone: StateTone.error,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const StateLoading();
        }
        if (!snapshot.hasData) {
          return StateMessage(title: emptyTitle, detail: emptyDetail);
        }
        return builder(context, snapshot.requireData);
      },
    );
  }
}
