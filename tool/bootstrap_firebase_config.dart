import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final configPath = _configPath(args);
  final configFile = File(configPath);

  if (!configFile.existsSync()) {
    stderr.writeln(
      'Missing Firebase config file: $configPath\n'
      'Copy firebase-config.example.json to one of the ignored files such as '
      '.firebase-config.dev.json and fill in the real values.',
    );
    exitCode = 64;
    return;
  }

  final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final outputFile = File('android/app/google-services.json');

  outputFile.createSync(recursive: true);
  outputFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(_googleServicesJson(config))}\n',
  );
}

String _configPath(List<String> args) {
  final index = args.indexOf('--config-file');
  if (index != -1 && index + 1 < args.length) {
    return args[index + 1];
  }

  return '.firebase-config.dev.json';
}

Map<String, dynamic> _googleServicesJson(Map<String, dynamic> config) {
  return <String, dynamic>{
    'project_info': <String, dynamic>{
      'project_number': _required(config, 'FIREBASE_PROJECT_NUMBER'),
      'project_id': _required(config, 'FIREBASE_PROJECT_ID'),
      'storage_bucket': _required(config, 'FIREBASE_STORAGE_BUCKET'),
    },
    'client': <Map<String, dynamic>>[
      <String, dynamic>{
        'client_info': <String, dynamic>{
          'mobilesdk_app_id': _required(config, 'FIREBASE_APP_ID'),
          'android_client_info': <String, dynamic>{
            'package_name': _required(config, 'FIREBASE_ANDROID_PACKAGE_NAME'),
          },
        },
        'oauth_client': <Map<String, dynamic>>[
          <String, dynamic>{
            'client_id': _required(config, 'FIREBASE_ANDROID_CLIENT_ID'),
            'client_type': 1,
            'android_info': <String, dynamic>{
              'package_name': _required(config, 'FIREBASE_ANDROID_PACKAGE_NAME'),
              'certificate_hash':
                  _required(config, 'FIREBASE_ANDROID_CERTIFICATE_HASH'),
            },
          },
          <String, dynamic>{
            'client_id': _required(config, 'FIREBASE_ANDROID_WEB_CLIENT_ID'),
            'client_type': 3,
          },
        ],
        'api_key': <Map<String, dynamic>>[
          <String, dynamic>{
            'current_key': _required(config, 'FIREBASE_API_KEY'),
          },
        ],
        'services': <String, dynamic>{
          'appinvite_service': <String, dynamic>{
            'other_platform_oauth_client': <Map<String, dynamic>>[
              <String, dynamic>{
                'client_id': _required(config, 'FIREBASE_ANDROID_WEB_CLIENT_ID'),
                'client_type': 3,
              },
            ],
          },
        },
      },
    ],
    'configuration_version': '1',
  };
}

String _required(Map<String, dynamic> config, String key) {
  final value = config[key];
  if (value == null || value.toString().trim().isEmpty) {
    stderr.writeln('Missing required Firebase config value: $key');
    exitCode = 64;
    exit(64);
  }

  return value.toString();
}