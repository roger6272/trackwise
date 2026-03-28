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
import 'package:firebase_remote_config/firebase_remote_config.dart' as _i627;
import 'package:firebase_storage/firebase_storage.dart' as _i457;
import 'package:get_it/get_it.dart' as _i174;
import 'package:google_sign_in/google_sign_in.dart' as _i116;
import 'package:injectable/injectable.dart' as _i526;
import 'package:traxelos/core/di/register_module.dart' as _i37;
import 'package:traxelos/core/services/analytics_service.dart' as _i954;
import 'package:traxelos/core/services/connectivity_service.dart' as _i394;
import 'package:traxelos/core/services/crashlytics_service.dart' as _i729;
import 'package:traxelos/core/services/performance_service.dart' as _i826;
import 'package:traxelos/core/state/app_ui_state.dart' as _i625;
import 'package:traxelos/features/auth/data/datasources/auth_firebase_datasource.dart'
    as _i810;
import 'package:traxelos/features/auth/data/datasources/auth_firebase_datasource_impl.dart'
    as _i823;
import 'package:traxelos/features/auth/data/repositories/auth_repository_impl.dart'
    as _i319;
import 'package:traxelos/features/auth/data/repositories/user_repository_impl.dart'
    as _i482;
import 'package:traxelos/features/auth/domain/repositories/auth_repository.dart'
    as _i259;
import 'package:traxelos/features/auth/domain/repositories/user_repository.dart'
    as _i721;
import 'package:traxelos/features/auth/domain/usecases/reset_password_usecase.dart'
    as _i868;
import 'package:traxelos/features/auth/domain/usecases/sign_in_with_apple_usecase.dart'
    as _i542;
import 'package:traxelos/features/auth/domain/usecases/sign_in_with_email_usecase.dart'
    as _i27;
import 'package:traxelos/features/auth/domain/usecases/sign_in_with_google_usecase.dart'
    as _i683;
import 'package:traxelos/features/auth/domain/usecases/sign_out_usecase.dart'
    as _i273;
import 'package:traxelos/features/auth/domain/usecases/sign_up_usecase.dart'
    as _i796;
import 'package:traxelos/features/auth/domain/usecases/watch_auth_state_usecase.dart'
    as _i563;
import 'package:traxelos/features/auth/presentation/bloc/auth_bloc.dart'
    as _i977;
import 'package:traxelos/features/bluetooth/data/datasources/bluetooth_datasource.dart'
    as _i933;
import 'package:traxelos/features/bluetooth/data/datasources/bluetooth_datasource_impl.dart'
    as _i607;
import 'package:traxelos/features/bluetooth/data/repositories/bluetooth_repository_impl.dart'
    as _i659;
import 'package:traxelos/features/bluetooth/domain/repositories/bluetooth_repository.dart'
    as _i649;
import 'package:traxelos/features/bluetooth/domain/usecases/check_bluetooth_enabled_usecase.dart'
    as _i896;
import 'package:traxelos/features/bluetooth/domain/usecases/clear_device_logs_usecase.dart'
    as _i973;
import 'package:traxelos/features/bluetooth/domain/usecases/connect_device_usecase.dart'
    as _i597;
import 'package:traxelos/features/bluetooth/domain/usecases/disconnect_device_usecase.dart'
    as _i368;
import 'package:traxelos/features/bluetooth/domain/usecases/refresh_device_items_usecase.dart'
    as _i905;
import 'package:traxelos/features/bluetooth/domain/usecases/request_bluetooth_permissions_usecase.dart'
    as _i937;
import 'package:traxelos/features/bluetooth/domain/usecases/request_device_data_usecase.dart'
    as _i902;
import 'package:traxelos/features/bluetooth/domain/usecases/scan_devices_usecase.dart'
    as _i1033;
import 'package:traxelos/features/bluetooth/domain/usecases/send_items_to_device_usecase.dart'
    as _i906;
import 'package:traxelos/features/bluetooth/domain/usecases/send_selected_item_usecase.dart'
    as _i594;
import 'package:traxelos/features/bluetooth/domain/usecases/send_time_sync_usecase.dart'
    as _i1041;
import 'package:traxelos/features/bluetooth/domain/usecases/stop_scan_usecase.dart'
    as _i177;
import 'package:traxelos/features/bluetooth/domain/usecases/sync_device_data_usecase.dart'
    as _i1008;
import 'package:traxelos/features/bluetooth/domain/usecases/sync_usecase.dart'
    as _i62;
import 'package:traxelos/features/bluetooth/domain/usecases/unpair_device_usecase.dart'
    as _i895;
import 'package:traxelos/features/bluetooth/domain/usecases/watch_connection_state_usecase.dart'
    as _i778;
import 'package:traxelos/features/bluetooth/domain/usecases/watch_device_messages_usecase.dart'
    as _i471;
import 'package:traxelos/features/bluetooth/presentation/bloc/bluetooth_bloc.dart'
    as _i531;
import 'package:traxelos/features/categories/data/datasources/category_remote_datasource.dart'
    as _i868;
import 'package:traxelos/features/categories/data/datasources/category_remote_datasource_impl.dart'
    as _i162;
import 'package:traxelos/features/categories/data/repositories/category_repository_impl.dart'
    as _i887;
import 'package:traxelos/features/categories/domain/repositories/category_repository.dart'
    as _i531;
import 'package:traxelos/features/categories/domain/usecases/create_category_usecase.dart'
    as _i409;
import 'package:traxelos/features/categories/domain/usecases/delete_category_usecase.dart'
    as _i923;
import 'package:traxelos/features/categories/domain/usecases/get_categories_usecase.dart'
    as _i622;
import 'package:traxelos/features/categories/domain/usecases/reorder_categories_usecase.dart'
    as _i349;
import 'package:traxelos/features/categories/domain/usecases/update_category_usecase.dart'
    as _i810;
import 'package:traxelos/features/categories/domain/usecases/watch_categories_usecase.dart'
    as _i789;
import 'package:traxelos/features/categories/presentation/bloc/categories_bloc.dart'
    as _i631;
import 'package:traxelos/features/charts/domain/usecases/get_chart_data_usecase.dart'
    as _i974;
import 'package:traxelos/features/charts/domain/usecases/get_cumulative_chart_data_usecase.dart'
    as _i962;
import 'package:traxelos/features/charts/presentation/bloc/charts_bloc.dart'
    as _i440;
import 'package:traxelos/features/events/data/datasources/event_log_remote_datasource.dart'
    as _i109;
import 'package:traxelos/features/events/data/datasources/event_log_remote_datasource_impl.dart'
    as _i472;
import 'package:traxelos/features/events/data/repositories/event_log_repository_impl.dart'
    as _i978;
import 'package:traxelos/features/events/domain/repositories/event_log_repository.dart'
    as _i153;
import 'package:traxelos/features/events/domain/usecases/delete_events_for_item_usecase.dart'
    as _i808;
import 'package:traxelos/features/events/domain/usecases/get_events_by_date_range_usecase.dart'
    as _i921;
import 'package:traxelos/features/events/domain/usecases/get_events_by_item_usecase.dart'
    as _i12;
import 'package:traxelos/features/events/domain/usecases/insert_events_usecase.dart'
    as _i762;
import 'package:traxelos/features/events/presentation/bloc/events_bloc.dart'
    as _i251;
import 'package:traxelos/features/export/data/datasources/firestore_mail_datasource.dart'
    as _i242;
import 'package:traxelos/features/export/data/datasources/firestore_mail_datasource_impl.dart'
    as _i305;
import 'package:traxelos/features/export/domain/usecases/generate_csv_usecase.dart'
    as _i804;
import 'package:traxelos/features/export/domain/usecases/send_email_with_csv_usecase.dart'
    as _i429;
import 'package:traxelos/features/export/presentation/bloc/export_bloc.dart'
    as _i164;
import 'package:traxelos/features/items/data/datasources/item_remote_datasource.dart'
    as _i694;
import 'package:traxelos/features/items/data/datasources/item_remote_datasource_impl.dart'
    as _i93;
import 'package:traxelos/features/items/data/repositories/item_repository_impl.dart'
    as _i1019;
import 'package:traxelos/features/items/domain/repositories/item_repository.dart'
    as _i452;
import 'package:traxelos/features/items/domain/usecases/create_item_usecase.dart'
    as _i214;
import 'package:traxelos/features/items/domain/usecases/delete_item_usecase.dart'
    as _i593;
import 'package:traxelos/features/items/domain/usecases/get_items_usecase.dart'
    as _i1021;
import 'package:traxelos/features/items/domain/usecases/increment_item_usecase.dart'
    as _i477;
import 'package:traxelos/features/items/domain/usecases/update_item_usecase.dart'
    as _i672;
import 'package:traxelos/features/items/domain/usecases/watch_items_usecase.dart'
    as _i165;
import 'package:traxelos/features/items/presentation/bloc/deleted_items_bloc.dart'
    as _i7;
import 'package:traxelos/features/items/presentation/bloc/items_bloc.dart'
    as _i380;
import 'package:traxelos/features/ota/data/datasources/ota_ble_datasource.dart'
    as _i126;
import 'package:traxelos/features/ota/data/datasources/ota_ble_datasource_impl.dart'
    as _i433;
import 'package:traxelos/features/ota/data/datasources/ota_remote_datasource.dart'
    as _i1017;
import 'package:traxelos/features/ota/data/datasources/ota_remote_datasource_impl.dart'
    as _i857;
import 'package:traxelos/features/ota/data/repositories/ota_repository_impl.dart'
    as _i970;
import 'package:traxelos/features/ota/domain/repositories/ota_repository.dart'
    as _i1036;
import 'package:traxelos/features/ota/domain/usecases/check_for_update.dart'
    as _i1014;
import 'package:traxelos/features/ota/domain/usecases/perform_ota_update.dart'
    as _i555;
import 'package:traxelos/features/profile/data/datasources/profile_remote_datasource.dart'
    as _i892;
import 'package:traxelos/features/profile/data/datasources/profile_remote_datasource_impl.dart'
    as _i875;
import 'package:traxelos/features/profile/data/repositories/profile_repository_impl.dart'
    as _i693;
import 'package:traxelos/features/profile/domain/repositories/profile_repository.dart'
    as _i401;
import 'package:traxelos/features/profile/domain/usecases/delete_account_usecase.dart'
    as _i833;
import 'package:traxelos/features/profile/domain/usecases/export_user_data_usecase.dart'
    as _i524;
import 'package:traxelos/features/profile/domain/usecases/get_profile_usecase.dart'
    as _i740;
import 'package:traxelos/features/profile/domain/usecases/update_profile_usecase.dart'
    as _i759;
import 'package:traxelos/features/profile/presentation/bloc/profile_bloc.dart'
    as _i943;

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
    gh.lazySingleton<_i625.AppUiState>(() => registerModule.appUiState);
    gh.lazySingleton<_i895.Connectivity>(() => registerModule.connectivity);
    gh.lazySingleton<_i457.FirebaseStorage>(
        () => registerModule.firebaseStorage);
    gh.lazySingleton<_i627.FirebaseRemoteConfig>(
        () => registerModule.firebaseRemoteConfig);
    gh.lazySingleton<_i954.AnalyticsService>(
        () => _i954.AnalyticsService.create());
    gh.lazySingleton<_i729.CrashlyticsService>(
        () => _i729.CrashlyticsService.create());
    gh.lazySingleton<_i826.PerformanceService>(
        () => _i826.PerformanceService.create());
    gh.lazySingleton<_i109.EventLogRemoteDataSource>(() =>
        _i472.EventLogRemoteDataSourceImpl(gh<_i974.FirebaseFirestore>()));
    gh.lazySingleton<_i394.ConnectivityService>(() =>
        _i394.ConnectivityServiceImpl(connectivity: gh<_i895.Connectivity>()));
    gh.lazySingleton<_i1017.OtaRemoteDataSource>(
        () => _i857.OtaRemoteDataSourceImpl(
              gh<_i457.FirebaseStorage>(),
              gh<_i627.FirebaseRemoteConfig>(),
            ));
    gh.lazySingleton<_i933.BluetoothDataSource>(
        () => _i607.BluetoothDataSourceImpl());
    gh.lazySingleton<_i153.EventLogRepository>(
        () => _i978.EventLogRepositoryImpl(
              gh<_i109.EventLogRemoteDataSource>(),
              gh<_i59.FirebaseAuth>(),
            ));
    gh.lazySingleton<_i694.ItemRemoteDataSource>(
        () => _i93.ItemRemoteDataSourceImpl(gh<_i974.FirebaseFirestore>()));
    gh.lazySingleton<_i808.DeleteEventsForItemUseCase>(
        () => _i808.DeleteEventsForItemUseCase(gh<_i153.EventLogRepository>()));
    gh.lazySingleton<_i921.GetEventsByDateRangeUseCase>(() =>
        _i921.GetEventsByDateRangeUseCase(gh<_i153.EventLogRepository>()));
    gh.lazySingleton<_i12.GetEventsByItemUseCase>(
        () => _i12.GetEventsByItemUseCase(gh<_i153.EventLogRepository>()));
    gh.lazySingleton<_i762.InsertEventsUseCase>(
        () => _i762.InsertEventsUseCase(gh<_i153.EventLogRepository>()));
    gh.lazySingleton<_i868.CategoryRemoteDataSource>(() =>
        _i162.CategoryRemoteDataSourceImpl(gh<_i974.FirebaseFirestore>()));
    gh.lazySingleton<_i126.OtaBleDatasource>(
        () => _i433.OtaBleDatasourceImpl(gh<_i933.BluetoothDataSource>()));
    gh.factory<_i251.EventsBloc>(() => _i251.EventsBloc(
          getEventsByDateRangeUseCase: gh<_i921.GetEventsByDateRangeUseCase>(),
          getEventsByItemUseCase: gh<_i12.GetEventsByItemUseCase>(),
          insertEventsUseCase: gh<_i762.InsertEventsUseCase>(),
        ));
    gh.lazySingleton<_i242.FirestoreMailDataSource>(() =>
        _i305.FirestoreMailDataSourceImpl(
            firestore: gh<_i974.FirebaseFirestore>()));
    gh.lazySingleton<_i721.UserRepository>(() => _i482.UserRepositoryImpl(
          firebaseAuth: gh<_i59.FirebaseAuth>(),
          firestore: gh<_i974.FirebaseFirestore>(),
        ));
    gh.lazySingleton<_i892.ProfileRemoteDataSource>(
        () => _i875.ProfileRemoteDataSourceImpl(
              firebaseAuth: gh<_i59.FirebaseAuth>(),
              firestore: gh<_i974.FirebaseFirestore>(),
            ));
    gh.lazySingleton<_i810.AuthFirebaseDataSource>(
        () => _i823.AuthFirebaseDataSourceImpl(
              firebaseAuth: gh<_i59.FirebaseAuth>(),
              firestore: gh<_i974.FirebaseFirestore>(),
              googleSignIn: gh<_i116.GoogleSignIn>(),
            ));
    gh.lazySingleton<_i452.ItemRepository>(() => _i1019.ItemRepositoryImpl(
          gh<_i694.ItemRemoteDataSource>(),
          gh<_i153.EventLogRepository>(),
        ));
    gh.lazySingleton<_i401.ProfileRepository>(() => _i693.ProfileRepositoryImpl(
        dataSource: gh<_i892.ProfileRemoteDataSource>()));
    gh.lazySingleton<_i649.BluetoothRepository>(
        () => _i659.BluetoothRepositoryImpl(gh<_i933.BluetoothDataSource>()));
    gh.lazySingleton<_i593.DeleteItemUseCase>(
        () => _i593.DeleteItemUseCase(gh<_i452.ItemRepository>()));
    gh.lazySingleton<_i1021.GetItemsUseCase>(
        () => _i1021.GetItemsUseCase(gh<_i452.ItemRepository>()));
    gh.lazySingleton<_i477.IncrementItemUseCase>(
        () => _i477.IncrementItemUseCase(gh<_i452.ItemRepository>()));
    gh.lazySingleton<_i672.UpdateItemUseCase>(
        () => _i672.UpdateItemUseCase(gh<_i452.ItemRepository>()));
    gh.lazySingleton<_i165.WatchItemsUseCase>(
        () => _i165.WatchItemsUseCase(gh<_i452.ItemRepository>()));
    gh.lazySingleton<_i531.CategoryRepository>(() =>
        _i887.CategoryRepositoryImpl(gh<_i868.CategoryRemoteDataSource>()));
    gh.lazySingleton<_i974.GetChartDataUseCase>(() => _i974.GetChartDataUseCase(
          gh<_i153.EventLogRepository>(),
          gh<_i452.ItemRepository>(),
        ));
    gh.lazySingleton<_i962.GetCumulativeChartDataUseCase>(
        () => _i962.GetCumulativeChartDataUseCase(
              gh<_i153.EventLogRepository>(),
              gh<_i452.ItemRepository>(),
            ));
    gh.lazySingleton<_i62.PerformSyncUseCase>(() => _i62.PerformSyncUseCase(
          gh<_i649.BluetoothRepository>(),
          gh<_i721.UserRepository>(),
          gh<_i394.ConnectivityService>(),
        ));
    gh.lazySingleton<_i905.RefreshDeviceItemsUseCase>(
        () => _i905.RefreshDeviceItemsUseCase(
              gh<_i452.ItemRepository>(),
              gh<_i531.CategoryRepository>(),
              gh<_i649.BluetoothRepository>(),
              gh<_i721.UserRepository>(),
            ));
    gh.lazySingleton<_i1008.SyncDeviceDataUseCase>(
        () => _i1008.SyncDeviceDataUseCase(
              gh<_i452.ItemRepository>(),
              gh<_i153.EventLogRepository>(),
            ));
    gh.lazySingleton<_i1036.OtaRepository>(() => _i970.OtaRepositoryImpl(
          gh<_i1017.OtaRemoteDataSource>(),
          gh<_i126.OtaBleDatasource>(),
        ));
    gh.lazySingleton<_i214.CreateItemUseCase>(() => _i214.CreateItemUseCase(
          gh<_i452.ItemRepository>(),
          gh<_i153.EventLogRepository>(),
        ));
    gh.factory<_i440.ChartsBloc>(() => _i440.ChartsBloc(
          getChartDataUseCase: gh<_i974.GetChartDataUseCase>(),
          getCumulativeChartDataUseCase:
              gh<_i962.GetCumulativeChartDataUseCase>(),
        ));
    gh.lazySingleton<_i896.CheckBluetoothEnabledUseCase>(() =>
        _i896.CheckBluetoothEnabledUseCase(gh<_i649.BluetoothRepository>()));
    gh.lazySingleton<_i973.ClearDeviceLogsUseCase>(
        () => _i973.ClearDeviceLogsUseCase(gh<_i649.BluetoothRepository>()));
    gh.lazySingleton<_i597.ConnectDeviceUseCase>(
        () => _i597.ConnectDeviceUseCase(gh<_i649.BluetoothRepository>()));
    gh.lazySingleton<_i368.DisconnectDeviceUseCase>(
        () => _i368.DisconnectDeviceUseCase(gh<_i649.BluetoothRepository>()));
    gh.lazySingleton<_i937.RequestBluetoothPermissionsUseCase>(() =>
        _i937.RequestBluetoothPermissionsUseCase(
            gh<_i649.BluetoothRepository>()));
    gh.lazySingleton<_i902.RequestDeviceDataUseCase>(
        () => _i902.RequestDeviceDataUseCase(gh<_i649.BluetoothRepository>()));
    gh.lazySingleton<_i1033.ScanDevicesUseCase>(
        () => _i1033.ScanDevicesUseCase(gh<_i649.BluetoothRepository>()));
    gh.lazySingleton<_i906.SendItemsToDeviceUseCase>(
        () => _i906.SendItemsToDeviceUseCase(gh<_i649.BluetoothRepository>()));
    gh.lazySingleton<_i594.SendSelectedItemUseCase>(
        () => _i594.SendSelectedItemUseCase(gh<_i649.BluetoothRepository>()));
    gh.lazySingleton<_i1041.SendTimeSyncUseCase>(
        () => _i1041.SendTimeSyncUseCase(gh<_i649.BluetoothRepository>()));
    gh.lazySingleton<_i177.StopScanUseCase>(
        () => _i177.StopScanUseCase(gh<_i649.BluetoothRepository>()));
    gh.lazySingleton<_i895.UnpairDeviceUseCase>(
        () => _i895.UnpairDeviceUseCase(gh<_i649.BluetoothRepository>()));
    gh.lazySingleton<_i778.WatchConnectionStateUseCase>(() =>
        _i778.WatchConnectionStateUseCase(gh<_i649.BluetoothRepository>()));
    gh.lazySingleton<_i471.WatchDeviceMessagesUseCase>(() =>
        _i471.WatchDeviceMessagesUseCase(gh<_i649.BluetoothRepository>()));
    gh.factory<_i380.ItemsBloc>(() => _i380.ItemsBloc(
          getItemsUseCase: gh<_i1021.GetItemsUseCase>(),
          watchItemsUseCase: gh<_i165.WatchItemsUseCase>(),
          createItemUseCase: gh<_i214.CreateItemUseCase>(),
          updateItemUseCase: gh<_i672.UpdateItemUseCase>(),
          deleteItemUseCase: gh<_i593.DeleteItemUseCase>(),
          incrementItemUseCase: gh<_i477.IncrementItemUseCase>(),
          itemRepository: gh<_i452.ItemRepository>(),
        ));
    gh.lazySingleton<_i833.DeleteAccountUseCase>(
        () => _i833.DeleteAccountUseCase(gh<_i401.ProfileRepository>()));
    gh.lazySingleton<_i524.ExportUserDataUseCase>(
        () => _i524.ExportUserDataUseCase(gh<_i401.ProfileRepository>()));
    gh.lazySingleton<_i740.GetProfileUseCase>(
        () => _i740.GetProfileUseCase(gh<_i401.ProfileRepository>()));
    gh.lazySingleton<_i759.UpdateProfileUseCase>(
        () => _i759.UpdateProfileUseCase(gh<_i401.ProfileRepository>()));
    gh.factory<_i7.DeletedItemsBloc>(
        () => _i7.DeletedItemsBloc(gh<_i452.ItemRepository>()));
    gh.factory<_i804.GenerateCSVUseCase>(() => _i804.GenerateCSVUseCase(
          gh<_i153.EventLogRepository>(),
          gh<_i452.ItemRepository>(),
          gh<_i531.CategoryRepository>(),
        ));
    gh.lazySingleton<_i1014.CheckForUpdateUseCase>(
        () => _i1014.CheckForUpdateUseCase(gh<_i1036.OtaRepository>()));
    gh.lazySingleton<_i555.PerformOtaUpdateUseCase>(
        () => _i555.PerformOtaUpdateUseCase(gh<_i1036.OtaRepository>()));
    gh.lazySingleton<_i259.AuthRepository>(() => _i319.AuthRepositoryImpl(
        dataSource: gh<_i810.AuthFirebaseDataSource>()));
    gh.lazySingleton<_i62.PerformOverrideUseCase>(
        () => _i62.PerformOverrideUseCase(
              gh<_i649.BluetoothRepository>(),
              gh<_i721.UserRepository>(),
              gh<_i452.ItemRepository>(),
              gh<_i531.CategoryRepository>(),
              gh<_i394.ConnectivityService>(),
            ));
    gh.lazySingleton<_i531.BluetoothBloc>(() => _i531.BluetoothBloc(
          gh<_i1033.ScanDevicesUseCase>(),
          gh<_i177.StopScanUseCase>(),
          gh<_i597.ConnectDeviceUseCase>(),
          gh<_i368.DisconnectDeviceUseCase>(),
          gh<_i778.WatchConnectionStateUseCase>(),
          gh<_i471.WatchDeviceMessagesUseCase>(),
          gh<_i906.SendItemsToDeviceUseCase>(),
          gh<_i594.SendSelectedItemUseCase>(),
          gh<_i1041.SendTimeSyncUseCase>(),
          gh<_i902.RequestDeviceDataUseCase>(),
          gh<_i973.ClearDeviceLogsUseCase>(),
          gh<_i895.UnpairDeviceUseCase>(),
          gh<_i896.CheckBluetoothEnabledUseCase>(),
          gh<_i937.RequestBluetoothPermissionsUseCase>(),
          gh<_i1008.SyncDeviceDataUseCase>(),
          gh<_i62.PerformSyncUseCase>(),
          gh<_i62.PerformOverrideUseCase>(),
          gh<_i905.RefreshDeviceItemsUseCase>(),
          gh<_i721.UserRepository>(),
          gh<_i649.BluetoothRepository>(),
          gh<_i452.ItemRepository>(),
        ));
    gh.lazySingleton<_i409.CreateCategoryUseCase>(
        () => _i409.CreateCategoryUseCase(gh<_i531.CategoryRepository>()));
    gh.lazySingleton<_i923.DeleteCategoryUseCase>(
        () => _i923.DeleteCategoryUseCase(gh<_i531.CategoryRepository>()));
    gh.lazySingleton<_i622.GetCategoriesUseCase>(
        () => _i622.GetCategoriesUseCase(gh<_i531.CategoryRepository>()));
    gh.lazySingleton<_i349.ReorderCategoriesUseCase>(
        () => _i349.ReorderCategoriesUseCase(gh<_i531.CategoryRepository>()));
    gh.lazySingleton<_i810.UpdateCategoryUseCase>(
        () => _i810.UpdateCategoryUseCase(gh<_i531.CategoryRepository>()));
    gh.lazySingleton<_i789.WatchCategoriesUseCase>(
        () => _i789.WatchCategoriesUseCase(gh<_i531.CategoryRepository>()));
    gh.factory<_i943.ProfileBloc>(() => _i943.ProfileBloc(
          getProfile: gh<_i740.GetProfileUseCase>(),
          updateProfile: gh<_i759.UpdateProfileUseCase>(),
          exportUserData: gh<_i524.ExportUserDataUseCase>(),
          deleteAccount: gh<_i833.DeleteAccountUseCase>(),
        ));
    gh.factory<_i868.ResetPasswordUseCase>(
        () => _i868.ResetPasswordUseCase(gh<_i259.AuthRepository>()));
    gh.factory<_i542.SignInWithAppleUseCase>(
        () => _i542.SignInWithAppleUseCase(gh<_i259.AuthRepository>()));
    gh.factory<_i27.SignInWithEmailUseCase>(
        () => _i27.SignInWithEmailUseCase(gh<_i259.AuthRepository>()));
    gh.factory<_i683.SignInWithGoogleUseCase>(
        () => _i683.SignInWithGoogleUseCase(gh<_i259.AuthRepository>()));
    gh.factory<_i273.SignOutUseCase>(
        () => _i273.SignOutUseCase(gh<_i259.AuthRepository>()));
    gh.factory<_i796.SignUpUseCase>(
        () => _i796.SignUpUseCase(gh<_i259.AuthRepository>()));
    gh.factory<_i563.WatchAuthStateUseCase>(
        () => _i563.WatchAuthStateUseCase(gh<_i259.AuthRepository>()));
    gh.factory<_i429.SendEmailWithCSVUseCase>(
        () => _i429.SendEmailWithCSVUseCase(
              mailDataSource: gh<_i242.FirestoreMailDataSource>(),
              generateCSV: gh<_i804.GenerateCSVUseCase>(),
            ));
    gh.factory<_i977.AuthBloc>(() => _i977.AuthBloc(
          signInWithEmail: gh<_i27.SignInWithEmailUseCase>(),
          signInWithGoogle: gh<_i683.SignInWithGoogleUseCase>(),
          signInWithApple: gh<_i542.SignInWithAppleUseCase>(),
          signUp: gh<_i796.SignUpUseCase>(),
          signOut: gh<_i273.SignOutUseCase>(),
          resetPassword: gh<_i868.ResetPasswordUseCase>(),
          watchAuthState: gh<_i563.WatchAuthStateUseCase>(),
          userRepository: gh<_i721.UserRepository>(),
        ));
    gh.factory<_i631.CategoriesBloc>(() => _i631.CategoriesBloc(
          watchCategoriesUseCase: gh<_i789.WatchCategoriesUseCase>(),
          createCategoryUseCase: gh<_i409.CreateCategoryUseCase>(),
          updateCategoryUseCase: gh<_i810.UpdateCategoryUseCase>(),
          deleteCategoryUseCase: gh<_i923.DeleteCategoryUseCase>(),
          reorderCategoriesUseCase: gh<_i349.ReorderCategoriesUseCase>(),
        ));
    gh.factory<_i164.ExportBloc>(() => _i164.ExportBloc(
        sendEmailWithCSVUseCase: gh<_i429.SendEmailWithCSVUseCase>()));
    return this;
  }
}

class _$RegisterModule extends _i37.RegisterModule {}
