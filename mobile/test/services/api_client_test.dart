import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('decodes utf8 json response', () async {
    final apiClient = ApiClient(
      httpClient: MockClient((http.Request request) async {
        expect(request.url.toString(), contains('/ping'));
        return http.Response.bytes(
          utf8.encode('{"message":"Привет"}'),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final response = await apiClient.getJson('/ping') as Map<String, dynamic>;

    expect(response['message'], 'Привет');
  });

  test('throws ApiException on non success response', () async {
    final apiClient = ApiClient(
      httpClient: MockClient((http.Request request) async {
        return http.Response.bytes(
          utf8.encode('{"message":"Недостаточно средств"}'),
          400,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    expect(
      () => apiClient.getJson('/broken'),
      throwsA(
        isA<ApiException>()
            .having((ApiException error) => error.statusCode, 'statusCode', 400)
            .having(
              (ApiException error) => error.message,
              'message',
              'Недостаточно средств',
            ),
      ),
    );
  });
}
