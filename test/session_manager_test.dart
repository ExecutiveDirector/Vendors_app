import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vendorapp/src/core/api/dio_client.dart';
import 'package:vendorapp/src/core/api/session_manager.dart';
import 'package:vendorapp/src/core/services/local_storage.dart';

typedef _Handler = Future<ResponseBody> Function(RequestOptions o);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final _Handler handler;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    calls++;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

DioException _offline(RequestOptions o) =>
    DioException(requestOptions: o, type: DioExceptionType.connectionError);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('vendor_hive');
    Hive.init(dir.path);
    await LocalStorage.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    LocalStorage.useSecureStorage(const FlutterSecureStorage());
    await LocalStorage.clearAll();
  });

  Dio refreshDio(_FakeAdapter a) => Dio(BaseOptions(baseUrl: 'http://x'))
    ..httpClientAdapter = a;

  group('SessionManager.refresh', () {
    test('no refresh token -> rejected', () async {
      expect(await SessionManager.refresh(), RefreshOutcome.rejected);
    });

    test('success stores the new access AND refresh token', () async {
      await LocalStorage.setToken('old');
      await LocalStorage.setRefreshToken('r1');
      final a = _FakeAdapter((o) async => _json(200, {'token': 'new', 'refreshToken': 'r2'}));
      SessionManager.dioFactory = () => refreshDio(a);

      expect(await SessionManager.refresh(), RefreshOutcome.renewed);
      expect(await LocalStorage.getToken(), 'new');
      expect(await LocalStorage.getRefreshToken(), 'r2');
    });

    test('server rejects the refresh token -> rejected', () async {
      await LocalStorage.setRefreshToken('r1');
      final a = _FakeAdapter((o) async => _json(401, {'error': 'Session has ended'}));
      SessionManager.dioFactory = () => refreshDio(a);
      expect(await SessionManager.refresh(), RefreshOutcome.rejected);
    });

    test('offline or server error -> unavailable, tokens kept', () async {
      await LocalStorage.setToken('keep');
      await LocalStorage.setRefreshToken('r1');
      SessionManager.dioFactory =
          () => refreshDio(_FakeAdapter((o) async => throw _offline(o)));
      expect(await SessionManager.refresh(), RefreshOutcome.unavailable);

      SessionManager.dioFactory =
          () => refreshDio(_FakeAdapter((o) async => _json(500, {'error': 'boom'})));
      expect(await SessionManager.refresh(), RefreshOutcome.unavailable);

      expect(await LocalStorage.getToken(), 'keep');
      expect(await LocalStorage.getRefreshToken(), 'r1');
    });

    test('simultaneous callers share a single renewal', () async {
      await LocalStorage.setRefreshToken('r1');
      final a = _FakeAdapter((o) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return _json(200, {'token': 'new', 'refreshToken': 'r2'});
      });
      SessionManager.dioFactory = () => refreshDio(a);

      final results = await Future.wait([
        SessionManager.refresh(),
        SessionManager.refresh(),
        SessionManager.refresh(),
      ]);
      expect(results, everyElement(RefreshOutcome.renewed));
      expect(a.calls, 1);
    });
  });

  group('ApiClient 401 handling', () {
    // The first call to the protected route fails with 401; after a
    // successful renewal the retry (carrying the new token) succeeds.
    test('renews silently and retries the original request', () async {
      await LocalStorage.setToken('expired');
      await LocalStorage.setRefreshToken('r1');
      SessionManager.dioFactory = () => refreshDio(
          _FakeAdapter((o) async => _json(200, {'token': 'fresh', 'refreshToken': 'r2'})));

      final api = _FakeAdapter((o) async {
        final auth = o.headers['Authorization'];
        return auth == 'Bearer fresh'
            ? _json(200, {'ok': true})
            : _json(401, {'error': 'jwt expired'});
      });
      ApiClient.dio.httpClientAdapter = api;

      final res = await ApiClient.dio.get('/vendors/orders');
      expect(res.statusCode, 200);
      expect(api.calls, 2);
      expect(await LocalStorage.getToken(), 'fresh');
    });

    test('being offline during renewal does NOT sign the vendor out', () async {
      await LocalStorage.setToken('expired');
      await LocalStorage.setRefreshToken('r1');
      SessionManager.dioFactory =
          () => refreshDio(_FakeAdapter((o) async => throw _offline(o)));
      ApiClient.dio.httpClientAdapter =
          _FakeAdapter((o) async => _json(401, {'error': 'jwt expired'}));

      await expectLater(
          ApiClient.dio.get('/vendors/orders'), throwsA(isA<DioException>()));
      expect(await LocalStorage.getToken(), 'expired');
      expect(await LocalStorage.getRefreshToken(), 'r1');
    });

    test('a rejected refresh token signs the vendor out', () async {
      await LocalStorage.setToken('expired');
      await LocalStorage.setRefreshToken('revoked');
      SessionManager.dioFactory = () =>
          refreshDio(_FakeAdapter((o) async => _json(401, {'error': 'Session has ended'})));
      ApiClient.dio.httpClientAdapter =
          _FakeAdapter((o) async => _json(401, {'error': 'jwt expired'}));

      await expectLater(
          ApiClient.dio.get('/vendors/orders'), throwsA(isA<DioException>()));
      expect(await LocalStorage.getToken(), isNull);
      expect(await LocalStorage.getRefreshToken(), isNull);
    });

    test('a wrong-password 401 on login never triggers a renewal', () async {
      await LocalStorage.setRefreshToken('r1');
      var renewals = 0;
      SessionManager.dioFactory = () => refreshDio(_FakeAdapter((o) async {
            renewals++;
            return _json(200, {'token': 't'});
          }));
      ApiClient.dio.httpClientAdapter =
          _FakeAdapter((o) async => _json(401, {'error': 'bad credentials'}));

      await expectLater(ApiClient.dio.post('/auth/login', data: {}),
          throwsA(isA<DioException>()));
      expect(renewals, 0);
    });
  });

  test('legacy plain-text tokens are migrated to secure storage', () async {
    await Hive.box('vendor_box').put('token', 'legacy');
    expect(await LocalStorage.getToken(), 'legacy');
    expect(Hive.box('vendor_box').get('token'), isNull);
    expect(await LocalStorage.getToken(), 'legacy'); // now served from secure storage
  });
}
