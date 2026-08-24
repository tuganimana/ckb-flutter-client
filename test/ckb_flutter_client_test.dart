import 'dart:convert';

import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _headerJson() => {
  'hash': '0xa5f5c85987a15de25661e5a214f2c1449cd803f071acc7999820f25246471f40',
  'number': '0x64',
  'parent_hash':
      '0x0000000000000000000000000000000000000000000000000000000000000000',
  'timestamp': '0x18c2e3c00',
  'epoch': '0x0',
  'compact_target': '0x1a09c30f',
  'dao': '0x0000000000000000000000000000000000000000000000000000000000000000',
  'nonce': '0x0',
  'transactions_root':
      '0x0000000000000000000000000000000000000000000000000000000000000000',
  'extra_hash':
      '0x0000000000000000000000000000000000000000000000000000000000000000',
  'proposals_hash':
      '0x0000000000000000000000000000000000000000000000000000000000000000',
  'version': '0x0',
};

CkbLightClient _clientWith(
  Future<http.Response> Function(http.Request) handler,
) {
  return CkbLightClient(httpClient: MockClient(handler));
}

void main() {
  test('parseHexUint and toHexUint round-trip', () {
    expect(parseHexUint('0x64'), 100);
    expect(parseHexUint('0x0'), 0);
    expect(toHexUint(100), '0x64');
  });

  test('getTipHeader parses a header', () async {
    final client = _clientWith((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['method'], 'get_tip_header');
      expect(body['params'], isEmpty);
      return http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': _headerJson(),
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final tip = await client.getTipHeader();
    expect(tip.numberInt, 100);
    expect(tip.hash, startsWith('0xa5f5'));
    client.close();
  });

  test('getCellsByLock sends a lock search key', () async {
    final lock = CkbScript.secp256k1Blake160(
      '0x5989ae415bb667931a99896e5fbbfad9ba53a223',
    );

    final client = _clientWith((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['method'], 'get_cells');
      final params = body['params'] as List<dynamic>;
      expect(params[0]['script_type'], 'lock');
      expect(params[0]['script']['args'], lock.args);
      expect(params[1], 'asc');
      expect(params[2], '0x32');
      return http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': {
            'last_cursor': '0xabc',
            'objects': [
              {
                'block_number': '0x10',
                'tx_index': '0x0',
                'out_point': {
                  'tx_hash':
                      '0xe8f2180dfba0cb15b45f771d520834515a5f8d7aa07f88894da88c22629b79e9',
                  'index': '0x0',
                },
                'output': {
                  'capacity': '0x174876e800',
                  'lock': lock.toJson(),
                  'type': null,
                },
                'output_data': '0x',
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final page = await client.getCellsByLock(lock);
    expect(page.objects, hasLength(1));
    expect(page.objects.first.output.capacityShannons, 100000000000);
    expect(page.lastCursor, '0xabc');
    client.close();
  });

  test('setScripts / getScripts round-trip payloads', () async {
    final script = ScriptStatus.lock(
      CkbScript.secp256k1Blake160('0x64257f00b6b63e987609fa9be2d0c86d351020fb'),
    );

    var call = 0;
    final client = _clientWith((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      call += 1;
      if (call == 1) {
        expect(body['method'], 'set_scripts');
        expect(body['params'][1], 'all');
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': null}),
          200,
        );
      }
      expect(body['method'], 'get_scripts');
      return http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': [script.toJson()],
        }),
        200,
      );
    });

    await client.setScripts([script]);
    final scripts = await client.getScripts();
    expect(scripts, hasLength(1));
    expect(scripts.first.script.args, script.script.args);
    client.close();
  });

  test('RPC error becomes CkbRpcException', () async {
    final client = _clientWith((request) async {
      return http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'error': {'code': -3, 'message': 'method not found'},
        }),
        200,
      );
    });

    expect(
      () => client.getTipHeader(),
      throwsA(
        isA<CkbRpcException>().having(
          (error) => error.message,
          'message',
          'method not found',
        ),
      ),
    );
    client.close();
  });

  test('fetchHeader parses fetched status', () async {
    final client = _clientWith((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['method'], 'fetch_header');
      return http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': {'status': 'fetched', 'data': _headerJson()},
        }),
        200,
      );
    });

    final status = await client.fetchHeader(_headerJson()['hash'] as String);
    expect(status.isFetched, isTrue);
    expect(status.data!.numberInt, 100);
    client.close();
  });
}
