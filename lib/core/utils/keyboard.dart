import 'package:flutter/widgets.dart';

/// Closes the keyboard and clears the remembered focus.
///
/// Call this before opening anything over a form (a picker sheet, a dialog, a
/// date picker). Without it Flutter remembers which text field was focused and
/// gives focus straight back to it when the sheet closes, so the keyboard pops
/// up again after every choice. `unfocus()` clears that memory as well.
void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();
