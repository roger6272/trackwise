/// Serialization utilities extracted from FlutterFlow.
/// Used by backend schema files for Firestore document serialization.

/// Parameter types for serialization/deserialization.
enum ParamType {
  int,
  double,
  String,
  bool,
  DateTime,
  DateTimeRange,
  LatLng,
  Color,
  FFPlace,
  FFUploadedFile,
  JSON,
  Document,
  DocumentReference,
  DataStruct,
  Enum,
  Action,
  Widget,
  Supabase,
  PostgresRow,
  SQLiteRow,
}

/// Builder function for deserializing structs.
typedef StructBuilder<T> = T Function(Map<String, dynamic> data);

/// Serializes a parameter to a string for URL encoding.
String? serializeParam(
  dynamic param,
  ParamType paramType, {
  bool isList = false,
}) {
  if (param == null) return null;
  if (isList) {
    return (param as List)
        .map((p) => serializeParam(p, paramType))
        .join(',');
  }
  switch (paramType) {
    case ParamType.int:
      return param.toString();
    case ParamType.double:
      return param.toString();
    case ParamType.String:
      return param;
    case ParamType.bool:
      return param ? 'true' : 'false';
    default:
      return param?.toString();
  }
}

/// Deserializes a string parameter back to its typed value.
T? deserializeParam<T>(
  dynamic param,
  ParamType paramType,
  bool isList, {
  StructBuilder<T>? structBuilder,
}) {
  if (param == null) return null;
  if (isList) {
    final values = (param as String).split(',');
    return values
        .map((v) => deserializeParam<T>(v, paramType, false))
        .whereType<T>()
        .toList() as T;
  }
  switch (paramType) {
    case ParamType.int:
      return int.tryParse(param.toString()) as T?;
    case ParamType.double:
      return double.tryParse(param.toString()) as T?;
    case ParamType.String:
      return param as T?;
    case ParamType.bool:
      return (param == 'true') as T?;
    default:
      return null;
  }
}

/// Safely casts a value to type T, handling int/double conversions.
T? castToType<T>(dynamic value) {
  if (value == null) {
    return null;
  }
  switch (T) {
    case double:
      // Doubles may be stored as ints in some cases.
      return value.toDouble() as T;
    case int:
      // Likewise, ints may be stored as doubles. If this is the case
      // (i.e. no decimal value), return the value as an int.
      if (value is num && value.toInt() == value) {
        return value.toInt() as T;
      }
      break;
    default:
      break;
  }
  return value as T;
}

/// Extension to filter null values from a List.
extension ListFilterExt<T> on Iterable<T?> {
  List<T> get withoutNulls => where((s) => s != null).map((e) => e!).toList();
}

/// Extension to filter null values from a Map.
extension MapFilterExtensions<T> on Map<String, T?> {
  Map<String, T> get withoutNulls => Map.fromEntries(
        entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value as T)),
      );
}
