import 'package:flutter/material.dart';

import '../../core/theme/theme_resolver.dart';

/// How long a message with an Undo stays up: long enough to notice and reach,
/// short enough that it isn't sitting in the way.
const Duration kUndoWindow = Duration(seconds: 10);

/// The two things every screen needs to say to the reader, in one place: a
/// short line at the bottom, and a yes/no question in the middle.
///
/// Messages replace whatever is already showing instead of queueing behind it,
/// so a burst of actions leaves the most recent line on screen rather than
/// making the reader wait out a backlog.
extension AppFeedback on BuildContext {
  /// Shows [message] at the bottom of the screen, optionally with one action.
  void showMessage(
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    assert(
      (actionLabel == null) == (onAction == null),
      'An action needs both a label and a callback.',
    );
    ScaffoldMessenger.of(this)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration ?? const Duration(seconds: 4),
          action: actionLabel == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction!),
        ),
      );
  }

  /// A message carrying a shortcut back out of what just happened. The action
  /// itself must stay available elsewhere (Trash, for instance), because the
  /// window closes on its own.
  void showUndoMessage(
    String message, {
    required VoidCallback onUndo,
    Duration duration = kUndoWindow,
  }) =>
      showMessage(
        message,
        duration: duration,
        actionLabel: 'Undo',
        onAction: onUndo,
      );

  /// Asks a yes/no question and resolves to false on cancel or dismissal.
  ///
  /// Pass [message] for plain prose, or [content] when the question needs a
  /// list or a summary. [destructive] tints the confirm button so a delete
  /// never looks like an ordinary Save.
  Future<bool> confirm({
    required String title,
    required String confirmLabel,
    String? message,
    Widget? content,
    String cancelLabel = 'Cancel',
    bool destructive = false,
    bool barrierDismissible = true,
  }) async {
    assert(
      (message == null) != (content == null),
      'Give the dialog either prose or a body, not both and not neither.',
    );
    final answer = await showDialog<bool>(
      context: this,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: content ?? Text(message!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: dialogContext.colors.critical,
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return answer ?? false;
  }
}
