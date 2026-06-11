import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class ApiConnectionHelp {
  ApiConnectionHelp._();

  static String connectionError(String apiBaseUrl) {
    final isLocalhost = apiBaseUrl.contains('localhost') || apiBaseUrl.contains('127.0.0.1');

    if (kIsWeb && isLocalhost) {
      return 'Cannot reach the API at $apiBaseUrl.\n\n'
          'This website is online but the API must run on your PC.\n\n'
          '1. On your PC: npm run dev (in biotime_backend)\n'
          '2. Expose it: ngrok http 3000\n'
          '3. Log out, then sign in again and paste the ngrok HTTPS URL '
          'in «رابط الباك اند»\n\n'
          'Same Wi‑Fi only: you can use http://YOUR_PC_IP:3000 instead of localhost.';
    }

    return 'Cannot reach the API at $apiBaseUrl.\n\n'
        'On your PC:\n'
        '  cd biotime_backend\n'
        '  npm run dev\n\n'
        'For testers on another network use ngrok:\n'
        '  ngrok http 3000';
  }
}
