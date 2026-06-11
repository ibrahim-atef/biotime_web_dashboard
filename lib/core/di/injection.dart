import 'package:get_it/get_it.dart';

import '../../data/api/biotime_api_client.dart';
import '../../features/auth/auth_cubit.dart';
import '../locale/locale_cubit.dart';
import '../storage/session_storage.dart';

final sl = GetIt.instance;

void configureDependencies() {
  sl.registerLazySingleton(SessionStorage.new);
  sl.registerLazySingleton(BioTimeApiClient.new);
  sl.registerLazySingleton(() => LocaleCubit(sl<SessionStorage>()));
  sl.registerLazySingleton(
    () => AuthCubit(api: sl<BioTimeApiClient>(), session: sl<SessionStorage>()),
  );
}

BioTimeApiClient get api => sl<BioTimeApiClient>();
SessionStorage get session => sl<SessionStorage>();
