import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ApiClient {
  final String id;
  final String name;
  final bool active;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? lastUsedAt;
  final int totalCalls;
  final int last7Days;
  final int last30Days;

  const ApiClient({
    required this.id,
    required this.name,
    required this.active,
    this.createdAt,
    this.createdBy,
    this.lastUsedAt,
    required this.totalCalls,
    required this.last7Days,
    required this.last30Days,
  });

  factory ApiClient.fromMap(Map<String, dynamic> data) {
    return ApiClient(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      active: data['active'] ?? true,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'] as String)
          : null,
      createdBy: data['createdBy'] as String?,
      lastUsedAt: data['lastUsedAt'] != null
          ? DateTime.tryParse(data['lastUsedAt'] as String)
          : null,
      totalCalls: (data['totalCalls'] as num?)?.toInt() ?? 0,
      last7Days: (data['last7Days'] as num?)?.toInt() ?? 0,
      last30Days: (data['last30Days'] as num?)?.toInt() ?? 0,
    );
  }
}

class ApiClientService extends ChangeNotifier {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  List<ApiClient> _clients = [];
  bool _isLoading = false;
  String? _error;

  List<ApiClient> get clients => _clients;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchClients() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('getApiClients');
      final result = await callable.call();

      if (result.data['clients'] != null) {
        _clients = (result.data['clients'] as List)
            .map((c) => ApiClient.fromMap(Map<String, dynamic>.from(c as Map)))
            .toList();
      } else {
        _clients = [];
      }
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Failed to fetch API clients';
      debugPrint('getApiClients error: $e');
    } catch (e) {
      _error = 'Failed to fetch API clients: $e';
      debugPrint('getApiClients error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> createClient(String name) async {
    try {
      final callable = _functions.httpsCallable('createApiClient');
      final result = await callable.call({'name': name});
      await fetchClients();
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to create API client');
    } catch (e) {
      throw Exception('Failed to create API client: $e');
    }
  }

  Future<void> updateClient({
    required String clientId,
    String? name,
    bool? active,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateApiClient');
      final data = <String, dynamic>{'clientId': clientId};
      if (name != null) data['name'] = name;
      if (active != null) data['active'] = active;
      await callable.call(data);
      await fetchClients();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to update API client');
    } catch (e) {
      throw Exception('Failed to update API client: $e');
    }
  }

  Future<void> deleteClient(String clientId) async {
    try {
      final callable = _functions.httpsCallable('deleteApiClient');
      await callable.call({'clientId': clientId});
      await fetchClients();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to delete API client');
    } catch (e) {
      throw Exception('Failed to delete API client: $e');
    }
  }

  Future<String?> regenerateKey(String clientId) async {
    try {
      final callable = _functions.httpsCallable('regenerateApiClientKey');
      final result = await callable.call({'clientId': clientId});
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['apiKey'] as String?;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to regenerate API key');
    } catch (e) {
      throw Exception('Failed to regenerate API key: $e');
    }
  }
}
