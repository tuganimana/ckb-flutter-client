import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exceptions.dart';

/// Minimal JSON-RPC 2.0 HTTP client used by [CkbLightClient].
class JsonRpcClient {
  JsonRpcClient({
    required this.rpcUrl,
    required this.httpClient,
    this.timeout = const Duration(seconds: 15),
  });

  final String rpcUrl;
  final http.Client httpClient;
  final Duration timeout;

  int _nextId = 0;

  Future<dynamic> call(String method, [List<dynamic> params = const []]) async {
    final id = ++_nextId;
    final response = await httpClient
        .post(
          Uri.parse(rpcUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': id,
            'jsonrpc': '2.0',
            'method': method,
            'params': params,
          }),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CkbRpcException.http(response.statusCode, response.body);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw CkbRpcException('Invalid JSON-RPC payload');
    }

    if (decoded['error'] != null) {
      throw CkbRpcException.fromRpc(decoded['error']);
    }

    return decoded['result'];
  }
}
