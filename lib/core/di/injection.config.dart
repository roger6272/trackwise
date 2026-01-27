// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:connectivity_plus/connectivity_plus.dart' as _i895;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:get_it/get_it.dart' as _i174;
import 'package:google_sign_in/google_sign_in.dart' as _i116;
import 'package:injectable/injectable.dart' as _i526;
import 'package:trackwise/core/di/register_module.dart' as _i510;
import 'package:trackwise/core/services/analytics_service.dart' as _i590;
import 'package:trackwise/core/services/connectivity_service.dart' as _i40;
import 'package:trackwise/core/services/crashlytics_service.dart' as _i813;
import 'package:trackwise/core/services/performance_service.dart' as _i1004;
import 'package:trackwise/core/state/app_ui_state.dart' as _i237;
import 'package:trackwise/features/auth/data/datasources/auth_firebase_datasource.dart'
    as _i647;
import 'package:trackwise/features/auth/data/datasources/auth_firebase_datasource_impl.dart'
    as _i459;
import 'package:trackwise/features/auth/data/repositories/auth_repository_impl.dart'
    as _i663;
import 'package:trackwise/features/auth/data/repositories/user_repository_impl.dart'
    as _i960;
import 'package:trackwise/features/auth/domain/repositories/auth_repository.dart'
    as _i578;
import 'package:trackwise/features/auth/domain/repositories/user_repository.dart'
    as _i881;
import 'package:trackwise/features/auth/domain/usecases/reset_password_usecase.dart'
    as _i517;
import 'package:trackwise/features/auth/domain/usecases/sign_in_with_apple_usecase.dart'
    as _i94;
import 'package:trackwise/features/auth/domain/usecases/sign_in_with_email_usecase.dart'
    as _i588;
import 'package:trackwise/features/auth/domain/usecases/sign_in_with_google_usecase.dart'
    as _i718;
import 'package:trackwise/features/auth/domain/usecases/sign_out_usecase.dart'
    as _i549;
import 'package:trackwise/features/auth/domain/usecases/sign_up_usecase.dart'
    as _i635;
import 'package:trackwise/features/auth/domain/usecases/watch_auth_state_usecase.dart'
    as _i28;
import 'package:trackwise/features/auth/presentation/bloc/auth_bloc.dart'
    as _i626;
import 'package:trackwise/features/bluetooth/data/datasources/bluetooth_datasource.dart'
    as _i1001;
import 'package:trackwise/features/bluetooth/data/datasources/bluetooth_datasource_impl.dart'
    as _i420;
import 'package:trackwise/features/bluetooth/data/repositories/bluetooth_repository_impl.dart'
    as _i516;
import 'package:trackwise/features/bluetooth/domain/repositories/bluetooth_repository.dart'
    as _i862;
import 'package:trackwise/features/bluetooth/domain/usecases/check_bluetooth_enabled_usecase.dart'
    as _i769;
import 'package:trackwise/features/bluetooth/domain/usecases/clear_device_logs_usecase.dart'
    as _i733;
import 'package:trackwise/features/bluetooth/domain/usecases/connect_device_usecase.dart'
    as _i679;
import 'package:trackwise/features/bluetooth/domain/usecases/disconnect_device_usecase.dart'
    as _i939;
import 'package:trackwise/features/bluetooth/domain/usecases/request_bluetooth_permissions_usecase.dart'
    as _i269;
import 'package:trackwise/features/bluetooth/domain/usecases/request_device_data_usecase.dart'
    as _i809;
import 'package:trackwise/features/bluetooth/domain/usecases/scan_devices_usecase.dart'
    as _i697;
import 'package:trackwise/features/bluetooth/domain/usecases/send_items_to_device_usecase.dart'
    as _i705;
import 'package:trackwise/features/bluetooth/domain/usecases/send_selected_item_usecase.dart'
    as _i884;
import 'package:trackwise/features/bluetooth/domain/usecases/send_time_sync_usecase.dart'
    as _i981;
import 'package:trackwise/features/bluetooth/domain/usecases/stop_scan_usecase.dart'
    as _i907;
import 'package:trackwise/features/bluetooth/domain/usecases/sync_device_data_usecase.dart'
    as _i833;
import 'package:trackwise/features/bluetooth/domain/usecases/sync_usecase.dart'
    as _i844;
import 'package:trackwise/features/bluetooth/domain/usecases/watch_connection_state_usecase.dart'
    as _i385;
import 'package:trackwise/features/bluetooth/domain/usecases/watch_device_messages_usecase.dart'
    as _i508;
import 'package:trackwise/features/bluetooth/presentation/bloc/bluetooth_bloc.dart'
    as _i72;
import 'package:trackwise/features/categories/data/datasources/category_remote_datasource.dart'
    as _i558;
import 'package:trackwise/features/categories/data/datasources/category_remote_datasource_impl.dart'
    as _i307;
import 'package:trackwise/features/categories/data/repositories/category_repository_impl.dart'
    as _i671;
import 'package:trackwise/features/categories/domain/repositories/category_repository.dart'
    as _i349;
import 'package:trackwise/features/categories/domain/usecases/create_category_usecase.dart'
    as _i624;
import 'package:trackwise/features/categories/domain/usecases/delete_category_usecase.dart'
    as _i742;
import 'package:trackwise/features/categories/domain/usecases/get_categories_usecase.dart'
    as _i956;
import 'package:trackwise/features/categories/domain/usecases/reorder_categories_usecase.dart'
    as _i412;
import 'package:trackwise/features/categories/domain/usecases/update_category_usecase.dart'
    as _i41;
import 'package:trackwise/features/categories/domain/usecases/watch_categories_usecase.dart'
    as _i269;
import 'package:trackwise/features/categories/presentation/bloc/categories_bloc.dart'
    as _i408;
import 'package:trackwise/features/charts/domain/usecases/get_chart_data_usecase.dart'
    as _i23;
import 'package:trackwise/features/charts/domain/usecases/get_cumulative_chart_data_usecase.dart'
    as _i1067;
import 'package:trackwise/features/charts/presentation/bloc/charts_bloc.dart'
    as _i802;
import 'package:trackwise/features/events/data/datasources/event_log_remote_datasource.dart'
    as _i949;
import 'package:trackwise/features/events/data/datasources/event_log_remote_datasource_impl.dart'
    as _i419;
import 'package:trackwise/features/events/data/repositories/event_log_repository_impl.dart'
    as _i579;
import 'package:trackwise/features/events/domain/repositories/event_log_repository.dart'
    as _i978;
import 'package:trackwise/features/events/domain/usecases/delete_events_for_item_usecase.dart'
    as _i1046;
import 'package:trackwise/features/events/domain/usecases/get_events_by_date_range_usecase.dart'
    as _i549;
import 'package:trackwise/features/events/domain/usecases/get_events_by_item_usecase.dart'
    as _i1052;
import 'package:trackwise/features/events/domain/usecases/insert_events_usecase.dart'
    as _i142;
import 'package:trackwise/features/events/presentation/bloc/events_bloc.dart'
    as _i1055;
import 'package:trackwise/features/export/data/datasources/firestore_mail_datasource.dart'
    as _i676;
import 'package:trackwise/features/export/data/datasources/firestore_mail_datasource_impl.dart'
    as _i588;
import 'package:trackwise/features/export/domain/usecases/generate_csv_usecase.dart'
    as _i1020;
import 'package:trackwise/features/export/domain/usecases/send_email_with_csv_usecase.dart'
    as _i963;
import 'package:trackwise/features/export/presentation/bloc/export_bloc.dart'
    as _i1061;
import 'package:trackwise/features/items/data/datasources/item_remote_datasource.dart'
    as _i41;
import 'package:trackwise/features/items/data/datasources/item_remote_datasource_impl.dart'
    as _i1046;
import 'package:trackwise/features/items/data/repositories/item_repository_impl.dart'
    as _i835;
import 'package:trackwise/features/items/domain/repositories/item_repository.dart'
    as _i319;
import 'package:trackwise/features/items/domain/usecases/create_item_usecase.dart'
    as _i311;
import 'package:trackwise/features/items/domain/usecases/delete_item_usecase.dart'
    as _i64;
import 'package:trackwise/features/items/domain/usecases/get_items_usecase.dart'
    as _i1010;
import 'package:trackwise/features/items/domain/usecases/increment_item_usecase.dart'
    as _i154;
import 'package:trackwise/features/items/domain/usecases/update_item_usecase.dart'
    as _i159;
import 'package:trackwise/features/items/domain/usecases/watch_items_usecase.dart'
    as _i307;
import 'package:trackwise/features/items/presentation/bloc/deleted_items_bloc.dart'
    as _i999;
import 'package:trackwise/features/items/presentation/bloc/items_bloc.dart'
    as _i913;
import 'package:trackwise/features/profile/data/datasources/profile_remote_datasource.dart'
    as _i772;
import 'package:trackwise/features/profile/data/datasources/profile_remote_datasource_impl.dart'
    as _i431;
import 'package:trackwise/features/profile/data/repositories/profile_repository_impl.dart'
    as _i950;
import 'package:trackwise/features/profile/domain/repositories/profile_repository.dart'
    as _i939;
import 'package:trackwise/features/profile/domain/usecases/delete_account_usecase.dart'
    as _i535;
import 'package:trackwise/features/profile/domain/usecases/export_user_data_usecase.dart'
    as _i764;
import 'package:trackwise/features/profile/domain/usecases/get_profile_usecase.dart'
    as _i582;
import 'package:trackwise/features/profile/domain/usecases/update_profile_usecase.dart'
    as _i373;
import 'package:trackwise/features/profile/presentation/bloc/profile_bloc.dart'
    as _i815;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final registerModule = _$RegisterModule();
    gh.lazySingleton<_i974.FirebaseFirestore>(() => registerModule.firestore);
    gh.lazySingleton<_i59.FirebaseAuth>(() => registerModule.firebaseAuth);
    gh.lazySingleton<_i116.GoogleSignIn>(() => registerModule.googleSignIn);
    gh.lazySingleton<_i237.AppUiState>(() => registerModule.appUiState);
    gh.lazySingleton<_i895.Connectivity>(() => registerModule.connectivity);
    gh.lazySingleton<_i590.AnalyticsService>(
        () => _i590.AnalyticsService.create());
    gh.lazySingleton<_i813.CrashlyticsService>(
        () => _i813.CrashlyticsService.create());
    gh.lazySingleton<_i1004.PerformanceService>(
        () => _i1004.PerformanceService.create());
    gh.lazySingleton<_i41.ItemRemoteDataSource>(
        () => _i1046.ItemRemoteDataSourceImpl(gh<_i974.FirebaseFirestore>()));
    gh.lazySingleton<_i1001.BluetoothDataSource>(
        () => _i420.BluetoothDataSourceImpl());
    gh.lazySingleton<_i40.ConnectivityService>(() =>
        _i40.ConnectivityServiceImpl(connectivity: gh<_i895.Connectivity>()));
    gh.lazySingleton<_i558.CategoryRemoteDataSource>(() =>
        _i307.CategoryRemoteDataSourceImpl(gh<_i974.FirebaseFirestore>()));
    gh.lazySingleton<_i949.EventLogRemoteDataSource>(() =>
        _i419.EventLogRemoteDataSourceImpl(gh<_i974.FirebaseFirestore>()));
    gh.lazySingleton<_i647.AuthFirebaseDataSource>(
        () => _i459.AuthFirebaseDataSourceImpl(
              firebaseAuth: gh<_i59.FirebaseAuth>(),
              firestore: gh<_i974.FirebaseFirestore>(),
              googleSignIn: gh<_i116.GoogleSignIn>(),
            ));
    gh.lazySingleton<_i676.FirestoreMailDataSource>(() =>
        _i588.FirestoreMailDataSourceImpl(
            firestore: gh<_i974.FirebaseFirestore>()));
    gh.lazySingleton<_i862.BluetoothRepository>(
        () => _i516.BluetoothRepositoryImpl(gh<_i1001.BluetoothDataSource>()));
    gh.lazySingleton<_i772.ProfileRemoteDataSource>(
        () => _i431.ProfileRemoteDataSourceImpl(
              firebaseAuth: gh<_i59.FirebaseAuth>(),
              firestore: gh<_i974.FirebaseFirestore>(),
            ));
    gh.lazySingleton<_i349.CategoryRepository>(() =>
        _i671.CategoryRepositoryImpl(gh<_i558.CategoryRemoteDataSource>()));
    gh.lazySingleton<_i881.UserRepository>(() => _i960.UserRepositoryImpl(
          firebaseAuth: gh<_i59.FirebaseAuth>(),
          firestore: gh<_i974.FirebaseFirestore>(),
        ));
    gh.lazySingleton<_i769.CheckBluetoothEnabledUseCase>(() =>
        _i769.CheckBluetoothEnabledUseCase(gh<_i862.BluetoothRepository>()));
    gh.lazySingleton<_i733.ClearDeviceLogsUseCase>(
        () => _i733.ClearDeviceLogsUseCase(gh<_i862.BluetoothRepository>()));
    gh.lazySingleton<_i679.ConnectDeviceUseCase>(
        () => _i679.ConnectDeviceUseCase(gh<_i862.BluetoothRepository>()));
    gh.lazySingleton<_i939.DisconnectDeviceUseCase>(
        () => _i939.DisconnectDeviceUseCase(gh<_i862.BluetoothRepository>()));
    gh.lazySingleton<_i269.RequestBluetoothPermissionsUseCase>(() =>
        _i269.RequestBluetoothPermissionsUseCase(
            gh<_i862.BluetoothRepository>()));
    gh.lazySingleton<_i809.RequestDeviceDataUseCase>(
        () => _i809.RequestDeviceDataUseCase(gh<_i862.BluetoothRepository>()));
    gh.lazySingleton<_i697.ScanDevicesUseCase>(
        () => _i697.ScanDevicesUseCase(gh<_i862.BluetoothRepository>()));
    gh.lazySingleton<_i705.SendItemsToDeviceUseCase>(
        () => _i705.SendItemsToDeviceUseCase(gh<_i862.BluetoothRepository>()));
    gh.lazySingleton<_i884.SendSelectedItemUseCase>(
        () => _i884.SendSelectedItemUseCase(gh<_i862.BluetoothRepository>()));
    gh.lazySingleton<_i981.SendTimeSyncUseCase>(
        () => _i981.SendTimeSyncUseCase(gh<_i862.BluetoothRepository>()));
    gh.lazySingleton<_i907.StopScanUseCase>(
        () => _i907.StopScanUseCase(gh<_i862.BluetoothRepository>()));
    gh.lazySingleton<_i385.WatchConnectionStateUseCase>(() =>
        _i385.WatchConnectionStateUseCase(gh<_i862.BluetoothRepository>()));
    gh.lazySingleton<_i508.WatchDeviceMessagesUseCase>(() =>
        _i508.WatchDeviceMessagesUseCase(gh<_i862.BluetoothRepository>()));
    gh.lazySingleton<_i578.AuthRepository>(() => _i663.AuthRepositoryImpl(
        dataSource: gh<_i647.AuthFirebaseDataSource>()));
    gh.lazySingleton<_i978.EventLogRepository>(
        () => _i579.EventLogRepositoryImpl(
              gh<_i949.EventLogRemoteDataSource>(),
              gh<_i59.FirebaseAuth>(),
            ));
    gh.lazySingleton<_i319.ItemRepository>(() => _i835.ItemRepositoryImpl(
          gh<_i41.ItemRemoteDataSource>(),
          gh<_i978.EventLogRepository>(),
        ));
    gh.lazySingleton<_i939.ProfileRepository>(() => _i950.ProfileRepositoryImpl(
        dataSource: gh<_i772.ProfileRemoteDataSource>()));
    gh.lazySingleton<_i23.GetChartDataUseCase>(() => _i23.GetChartDataUseCase(
          gh<_i978.EventLogRepository>(),
          gh<_i319.ItemRepository>(),
        ));
    gh.lazySingleton<_i1067.GetCumulativeChartDataUseCase>(
        () => _i1067.GetCumulativeChartDataUseCase(
              gh<_i978.EventLogRepository>(),
              gh<_i319.ItemRepository>(),
            ));
    gh.lazySingleton<_i833.SyncDeviceDataUseCase>(
        () => _i833.SyncDeviceDataUseCase(
              gh<_i319.ItemRepository>(),
              gh<_i978.EventLogRepository>(),
            ));
    gh.factory<_i999.DeletedItemsBloc>(
        () => _i999.DeletedItemsBloc(gh<_i319.ItemRepository>()));
    gh.lazySingleton<_i64.DeleteItemUseCase>(
        () => _i64.DeleteItemUseCase(gh<_i319.ItemRepository>()));
    gh.lazySingleton<_i1010.GetItemsUseCase>(
        () => _i1010.GetItemsUseCase(gh<_i319.ItemRepository>()));
    gh.lazySingleton<_i154.IncrementItemUseCase>(
        () => _i154.IncrementItemUseCase(gh<_i319.ItemRepository>()));
    gh.lazySingleton<_i159.UpdateItemUseCase>(
        () => _i159.UpdateItemUseCase(gh<_i319.ItemRepository>()));
    gh.lazySingleton<_i307.WatchItemsUseCase>(
        () => _i307.WatchItemsUseCase(gh<_i319.ItemRepository>()));
    gh.lazySingleton<_i535.DeleteAccountUseCase>(
        () => _i535.DeleteAccountUseCase(gh<_i939.ProfileRepository>()));
    gh.lazySingleton<_i764.ExportUserDataUseCase>(
        () => _i764.ExportUserDataUseCase(gh<_i939.ProfileRepository>()));
    gh.lazySingleton<_i582.GetProfileUseCase>(
        () => _i582.GetProfileUseCase(gh<_i939.ProfileRepository>()));
    gh.lazySingleton<_i373.UpdateProfileUseCase>(
        () => _i373.UpdateProfileUseCase(gh<_i939.ProfileRepository>()));
    gh.factory<_i815.ProfileBloc>(() => _i815.ProfileBloc(
          getProfile: gh<_i582.GetProfileUseCase>(),
          updateProfile: gh<_i373.UpdateProfileUseCase>(),
          exportUserData: gh<_i764.ExportUserDataUseCase>(),
          deleteAccount: gh<_i535.DeleteAccountUseCase>(),
        ));
    gh.factory<_i1020.GenerateCSVUseCase>(() => _i1020.GenerateCSVUseCase(
          gh<_i978.EventLogRepository>(),
          gh<_i319.ItemRepository>(),
          gh<_i349.CategoryRepository>(),
        ));
    gh.lazySingleton<_i624.CreateCategoryUseCase>(
        () => _i624.CreateCategoryUseCase(gh<_i349.CategoryRepository>()));
    gh.lazySingleton<_i742.DeleteCategoryUseCase>(
        () => _i742.DeleteCategoryUseCase(gh<_i349.CategoryRepository>()));
    gh.lazySingleton<_i956.GetCategoriesUseCase>(
        () => _i956.GetCategoriesUseCase(gh<_i349.CategoryRepository>()));
    gh.lazySingleton<_i412.ReorderCategoriesUseCase>(
        () => _i412.ReorderCategoriesUseCase(gh<_i349.CategoryRepository>()));
    gh.lazySingleton<_i41.UpdateCategoryUseCase>(
        () => _i41.UpdateCategoryUseCase(gh<_i349.CategoryRepository>()));
    gh.lazySingleton<_i269.WatchCategoriesUseCase>(
        () => _i269.WatchCategoriesUseCase(gh<_i349.CategoryRepository>()));
    gh.factory<_i802.ChartsBloc>(() => _i802.ChartsBloc(
          getChartDataUseCase: gh<_i23.GetChartDataUseCase>(),
          getCumulativeChartDataUseCase:
              gh<_i1067.GetCumulativeChartDataUseCase>(),
        ));
    gh.lazySingleton<_i844.PerformSyncUseCase>(() => _i844.PerformSyncUseCase(
          gh<_i862.BluetoothRepository>(),
          gh<_i881.UserRepository>(),
          gh<_i319.ItemRepository>(),
          gh<_i349.CategoryRepository>(),
          gh<_i40.ConnectivityService>(),
        ));
    gh.lazySingleton<_i844.PerformOverrideUseCase>(
        () => _i844.PerformOverrideUseCase(
              gh<_i862.BluetoothRepository>(),
              gh<_i881.UserRepository>(),
              gh<_i319.ItemRepository>(),
              gh<_i349.CategoryRepository>(),
              gh<_i40.ConnectivityService>(),
            ));
    gh.lazySingleton<_i311.CreateItemUseCase>(() => _i311.CreateItemUseCase(
          gh<_i319.ItemRepository>(),
          gh<_i978.EventLogRepository>(),
        ));
    gh.factory<_i517.ResetPasswordUseCase>(
        () => _i517.ResetPasswordUseCase(gh<_i578.AuthRepository>()));
    gh.factory<_i94.SignInWithAppleUseCase>(
        () => _i94.SignInWithAppleUseCase(gh<_i578.AuthRepository>()));
    gh.factory<_i588.SignInWithEmailUseCase>(
        () => _i588.SignInWithEmailUseCase(gh<_i578.AuthRepository>()));
    gh.factory<_i718.SignInWithGoogleUseCase>(
        () => _i718.SignInWithGoogleUseCase(gh<_i578.AuthRepository>()));
    gh.factory<_i549.SignOutUseCase>(
        () => _i549.SignOutUseCase(gh<_i578.AuthRepository>()));
    gh.factory<_i635.SignUpUseCase>(
        () => _i635.SignUpUseCase(gh<_i578.AuthRepository>()));
    gh.factory<_i28.WatchAuthStateUseCase>(
        () => _i28.WatchAuthStateUseCase(gh<_i578.AuthRepository>()));
    gh.lazySingleton<_i1046.DeleteEventsForItemUseCase>(() =>
        _i1046.DeleteEventsForItemUseCase(gh<_i978.EventLogRepository>()));
    gh.lazySingleton<_i549.GetEventsByDateRangeUseCase>(() =>
        _i549.GetEventsByDateRangeUseCase(gh<_i978.EventLogRepository>()));
    gh.lazySingleton<_i1052.GetEventsByItemUseCase>(
        () => _i1052.GetEventsByItemUseCase(gh<_i978.EventLogRepository>()));
    gh.lazySingleton<_i142.InsertEventsUseCase>(
        () => _i142.InsertEventsUseCase(gh<_i978.EventLogRepository>()));
    gh.factory<_i963.SendEmailWithCSVUseCase>(
        () => _i963.SendEmailWithCSVUseCase(
              mailDataSource: gh<_i676.FirestoreMailDataSource>(),
              generateCSV: gh<_i1020.GenerateCSVUseCase>(),
            ));
    gh.factory<_i1061.ExportBloc>(() => _i1061.ExportBloc(
        sendEmailWithCSVUseCase: gh<_i963.SendEmailWithCSVUseCase>()));
    gh.factory<_i626.AuthBloc>(() => _i626.AuthBloc(
          signInWithEmail: gh<_i588.SignInWithEmailUseCase>(),
          signInWithGoogle: gh<_i718.SignInWithGoogleUseCase>(),
          signInWithApple: gh<_i94.SignInWithAppleUseCase>(),
          signUp: gh<_i635.SignUpUseCase>(),
          signOut: gh<_i549.SignOutUseCase>(),
          resetPassword: gh<_i517.ResetPasswordUseCase>(),
          watchAuthState: gh<_i28.WatchAuthStateUseCase>(),
          userRepository: gh<_i881.UserRepository>(),
        ));
    gh.factory<_i408.CategoriesBloc>(() => _i408.CategoriesBloc(
          watchCategoriesUseCase: gh<_i269.WatchCategoriesUseCase>(),
          createCategoryUseCase: gh<_i624.CreateCategoryUseCase>(),
          updateCategoryUseCase: gh<_i41.UpdateCategoryUseCase>(),
          deleteCategoryUseCase: gh<_i742.DeleteCategoryUseCase>(),
          reorderCategoriesUseCase: gh<_i412.ReorderCategoriesUseCase>(),
        ));
    gh.factory<_i913.ItemsBloc>(() => _i913.ItemsBloc(
          getItemsUseCase: gh<_i1010.GetItemsUseCase>(),
          watchItemsUseCase: gh<_i307.WatchItemsUseCase>(),
          createItemUseCase: gh<_i311.CreateItemUseCase>(),
          updateItemUseCase: gh<_i159.UpdateItemUseCase>(),
          deleteItemUseCase: gh<_i64.DeleteItemUseCase>(),
          incrementItemUseCase: gh<_i154.IncrementItemUseCase>(),
          itemRepository: gh<_i319.ItemRepository>(),
        ));
    gh.lazySingleton<_i72.BluetoothBloc>(() => _i72.BluetoothBloc(
          gh<_i697.ScanDevicesUseCase>(),
          gh<_i907.StopScanUseCase>(),
          gh<_i679.ConnectDeviceUseCase>(),
          gh<_i939.DisconnectDeviceUseCase>(),
          gh<_i385.WatchConnectionStateUseCase>(),
          gh<_i508.WatchDeviceMessagesUseCase>(),
          gh<_i705.SendItemsToDeviceUseCase>(),
          gh<_i884.SendSelectedItemUseCase>(),
          gh<_i981.SendTimeSyncUseCase>(),
          gh<_i809.RequestDeviceDataUseCase>(),
          gh<_i733.ClearDeviceLogsUseCase>(),
          gh<_i769.CheckBluetoothEnabledUseCase>(),
          gh<_i269.RequestBluetoothPermissionsUseCase>(),
          gh<_i833.SyncDeviceDataUseCase>(),
          gh<_i844.PerformSyncUseCase>(),
          gh<_i844.PerformOverrideUseCase>(),
          gh<_i881.UserRepository>(),
          gh<_i862.BluetoothRepository>(),
        ));
    gh.factory<_i1055.EventsBloc>(() => _i1055.EventsBloc(
          getEventsByDateRangeUseCase: gh<_i549.GetEventsByDateRangeUseCase>(),
          getEventsByItemUseCase: gh<_i1052.GetEventsByItemUseCase>(),
          insertEventsUseCase: gh<_i142.InsertEventsUseCase>(),
        ));
    return this;
  }
}

class _$RegisterModule extends _i510.RegisterModule {}
