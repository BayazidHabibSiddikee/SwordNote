// Dart FFI bindings for the SwordTrack native model service.
// This file defines the native function signatures that Flutter calls.
library;

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

// Note: This uses Platform Channel approach instead of FFI for simplicity.
// The actual native bridge communicates via MethodChannel in the Kotlin side.
// See android/app/src/main/kotlin/com/swordtrack/swordtrack/ModelServicePlugin.kt
