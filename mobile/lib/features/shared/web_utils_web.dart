import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void requestWakeLock() {
  try {
    globalContext.callMethod('requestWakeLock'.toJS);
  } catch (e) {
    print("Wake lock error: $e");
  }
}

void releaseWakeLock() {
  try {
    globalContext.callMethod('releaseWakeLock'.toJS);
  } catch (e) {
    print("Wake lock error: $e");
  }
}

bool shareApp(String title, String text, String url) {
  try {
    final val = globalContext.callMethod('shareApp'.toJS, [title.toJS, text.toJS, url.toJS].toJS);
    if (val != null) {
      return (val as JSBoolean).toDart;
    }
  } catch (e) {
    print("Share error: $e");
  }
  return false;
}

void registerInstallCallback(void Function() callback) {
  try {
    globalContext['onAppInstallable'] = callback.toJS;
  } catch (e) {
    print("Error setting PWA install callback: $e");
  }
}

void triggerPWAInstall() {
  try {
    globalContext.callMethod('installPWA'.toJS);
  } catch (e) {
    print("Error invoking installPWA: $e");
  }
}

bool checkAppInstallable() {
  try {
    if (globalContext.hasProperty('isAppInstallable'.toJS).toDart) {
      final val = globalContext['isAppInstallable'];
      if (val != null) {
        return (val as JSBoolean).toDart;
      }
    }
  } catch (e) {
    print("Error checking isAppInstallable: $e");
  }
  return false;
}
