import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'presentation/providers/context_provider.dart';
import 'domain/repositories/i_symbol_repository.dart';
import 'domain/repositories/i_context_repository.dart';
import 'data/repositories/symbol_repository_impl.dart';
import 'data/sync/supabase_sync_service.dart';
import 'presentation/screens/board_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is optional when values are passed through --dart-define.
  }

  const urlFromDefine = String.fromEnvironment('SUPABASE_URL');
  const anonKeyFromDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
  final supabaseUrl = urlFromDefine.isNotEmpty
      ? urlFromDefine
      : (dotenv.env['SUPABASE_URL'] ?? '');
  final supabaseAnonKey = anonKeyFromDefine.isNotEmpty
      ? anonKeyFromDefine
      : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing Supabase configuration. Set SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define or .env.',
    );
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Request Hardware Permissions for Wi-Fi Scanning (Modern Android Requirement)
  await _requestPermissions();
  await _runInitialSyncIfAuthenticated();

  runApp(const AutiConnectApp());
}

Future<void> _requestPermissions() async {
  // Location is required for BSSID/SSID access on Android 10+
  Map<Permission, PermissionStatus> statuses = await [
    Permission.location,
    Permission.locationWhenInUse,
  ].request();
  
  if (statuses[Permission.location]?.isDenied ?? true) {
    debugPrint("Warning: Location permission denied. Wi-Fi scanning will return empty results.");
  }
}

Future<void> _runInitialSyncIfAuthenticated() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;

  final ids = await _resolveFamilyAndDeviceIds(client, user);
  final familyId = ids.$1;
  final resolvedDeviceId = ids.$2;
  if (familyId == null || familyId.isEmpty) {
    debugPrint('Initial sync skipped: family_id missing for authenticated user.');
    return;
  }

  final deviceId = (resolvedDeviceId == null || resolvedDeviceId.isEmpty)
      ? '${user.id}_mobile'
      : resolvedDeviceId;
  final syncService = SupabaseSyncService();

  try {
    await syncService.syncOnBoot(familyId);
    await syncService.flushOfflineQueue(familyId, deviceId);
  } catch (e) {
    debugPrint('Initial sync skipped: $e');
  }
}

Future<(String?, String?)> _resolveFamilyAndDeviceIds(
  SupabaseClient client,
  User user,
) async {
  String? familyId = user.userMetadata?['family_id']?.toString();
  String? deviceId = user.userMetadata?['device_id']?.toString();

  if ((familyId?.isNotEmpty ?? false) && (deviceId?.isNotEmpty ?? false)) {
    return (familyId, deviceId);
  }

  try {
    final row = await client
        .from('users')
        .select('family_id, device_id')
        .eq('auth_uid', user.id)
        .maybeSingle();

    if (row is Map<String, dynamic>) {
      familyId ??= row['family_id']?.toString();
      deviceId ??= row['device_id']?.toString();
    }
  } catch (e) {
    debugPrint('Unable to resolve family/device metadata from users table: $e');
  }

  return (familyId, deviceId);
}

class AutiConnectApp extends StatelessWidget {
  const AutiConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repositories
        Provider<ISymbolRepository>(create: (_) => SymbolRepositoryImpl()),
        Provider<IContextRepository>(create: (_) => ContextRepositoryImpl()),
        
        // Services
        Provider<SupabaseSyncService>(create: (_) => SupabaseSyncService()),

        // State Managers
        ChangeNotifierProvider<ContextProvider>(
          create: (context) => ContextProvider(
            contextRepository: context.read<IContextRepository>(),
            symbolRepository: context.read<ISymbolRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'AutiConnect',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        ),
        home: const BoardScreen(),
      ),
    );
  }
}
