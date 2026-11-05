import 'package:web/web.dart' as web;

bool openWebUrl(String url) {
  try {
    web.window.open(url, '_blank');
    return true;
  } catch (e) {
    return false;
  }
}
