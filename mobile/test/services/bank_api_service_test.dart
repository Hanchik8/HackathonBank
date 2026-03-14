import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/services/api_client.dart';
import 'package:hackathon_bank_mobile/services/bank_api_service.dart';
import 'package:hackathon_bank_mobile/services/mock_data_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.getResponses, this.postResponses)
    : super(
        httpClient: MockClient(
          (http.Request request) async => http.Response('', 500),
        ),
      );

  final Map<String, dynamic> getResponses;
  final Map<String, dynamic> postResponses;
  final Map<String, Object?> postBodies = <String, Object?>{};

  @override
  Future<dynamic> getJson(String path) async => getResponses[path];

  @override
  Future<dynamic> postJson(String path, {Object? body}) async {
    postBodies[path] = body;
    return postResponses[path];
  }
}

void main() {
  setUp(() {
    MockDataProvider.resetForTest();
  });

  test('maps backend payloads into typed models', () async {
    final now = DateTime.now();
    final expectedHorizon = DateTime(now.year, now.month + 1, 0)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final fakeApiClient = _FakeApiClient(
      <String, dynamic>{
        '/accounts': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': 'Main',
            'type': 'MAIN',
            'balance': 15000,
            'currency': 'KGS',
          },
        ],
        '/transactions': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'title': 'Groceries',
            'counterparty': 'Green Market',
            'amount': -3200,
            'category': 'Food',
            'iconKey': 'food',
            'type': 'PURCHASE',
            'status': 'COMPLETED',
            'accountName': 'Main',
            'occurredAt': '2026-03-12T09:05:00',
          },
        ],
        '/subscriptions': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'sub-1',
            'merchant': 'MPlus',
            'amount': 299,
            'currencyCode': 'KGS',
            'status': 'ACTIVE',
            'nextChargeDate': '2026-03-20T00:00:00Z',
          },
        ],
        '/ai/dashboard?offsetDays=$expectedHorizon': <String, dynamic>{
          'currentBalance': 15000,
          'savingsBalance': 50000,
          'minimumProjectedBalance': -10000,
          'horizonDays': expectedHorizon,
          'points': <Map<String, dynamic>>[
            <String, dynamic>{
              'dayOffset': 0,
              'isoDate': '2026-03-12',
              'label': '12 Mar',
              'balance': 15000,
            },
          ],
          'scheduledPayments': <Map<String, dynamic>>[],
        },
      },
      <String, dynamic>{
        '/ai/analyze': <String, dynamic>{
          'hasAlert': true,
          'message': 'Move money from savings',
          'actionToken': 'token-1',
        },
        '/ai/execute': <String, dynamic>{
          'success': true,
          'message': 'Done',
          'currentBalance': 25000,
          'savingsBalance': 40000,
        },
        '/scheduled-payments': <String, dynamic>{
          'id': 10,
          'accountId': 1,
          'accountName': 'Main',
          'title': 'Internet',
          'counterparty': 'HomeNet',
          'category': 'Subscriptions',
          'iconKey': 'subscription',
          'amount': 3900,
          'dueDate': '2026-03-18',
          'status': 'SCHEDULED',
        },
        '/transfer': <String, dynamic>{
          'message': 'Internal transfer completed.',
          'fromAccount': <String, dynamic>{
            'id': 1,
            'name': 'Main',
            'type': 'MAIN',
            'balance': 12000,
            'currency': 'KGS',
          },
          'toAccount': <String, dynamic>{
            'id': 2,
            'name': 'Savings',
            'type': 'SAVINGS',
            'balance': 53000,
            'currency': 'KGS',
          },
          'amount': 3000,
        },
        '/transfer/external': <String, dynamic>{
          'message': 'Transfer completed.',
          'fromAccount': <String, dynamic>{
            'id': 1,
            'name': 'Main',
            'type': 'MAIN',
            'balance': 12000,
            'currency': 'KGS',
          },
          'recipientType': 'USER',
          'recipientName': 'Aigerim',
          'amount': 3000,
        },
        '/subscriptions/sub-1/cancel': null,
      },
    );
    final apiService = BankApiService(apiClient: fakeApiClient);

    final accounts = await apiService.fetchAccounts();
    final transactions = await apiService.fetchTransactions();
    final subscriptions = await apiService.fetchSubscriptions();
    final dashboard = await apiService.fetchDashboard(7);
    final analysis = await apiService.analyzeCashFlow(7);
    final execution = await apiService.executeAction('token-1');
    final createdPayment = await apiService.createScheduledPayment(
      accountId: 1,
      title: 'Internet',
      counterparty: 'HomeNet',
      category: 'Subscriptions',
      amount: 3900,
      dueDate: DateTime(2026, 3, 18),
    );
    final internalTransfer = await apiService.transferBetweenAccounts(
      fromAccountId: 1,
      toAccountId: 2,
      amount: 3000,
    );
    final externalTransfer = await apiService.transferToRecipient(
      fromAccountId: 1,
      recipientType: 'USER',
      recipientName: 'Aigerim',
      amount: 3000,
    );
    await apiService.cancelSubscription('sub-1');

    expect(accounts.single.currency, 'KGS');
    expect(transactions.single.category, 'Food');
    expect(subscriptions.single.title, 'MPlus');
    expect(subscriptions.single.currency, 'KGS');
    expect(dashboard.horizonDays, expectedHorizon);
    expect(analysis.actionToken, 'token-1');
    expect(execution.currentBalance, 25000);
    expect(createdPayment.title, 'Internet');
    expect(createdPayment.isReminder, isTrue);
    expect(internalTransfer.toAccount?.name, 'Savings');
    expect(externalTransfer.recipientName, 'Aigerim');
    expect(fakeApiClient.postBodies['/ai/analyze'], <String, dynamic>{
      'offsetDays': 7,
    });
    expect(
      fakeApiClient.postBodies['/subscriptions/sub-1/cancel'],
      <String, dynamic>{},
    );
  });

  test('returns an empty list when subscriptions endpoint is absent', () async {
    final apiService = BankApiService(
      apiClient: _Subscriptions404ApiClient(),
    );

    final subscriptions = await apiService.fetchSubscriptions();

    expect(subscriptions, isEmpty);
  });
}

class _Subscriptions404ApiClient extends ApiClient {
  _Subscriptions404ApiClient()
    : super(
        httpClient: MockClient(
          (http.Request request) async => http.Response('', 500),
        ),
      );

  @override
  Future<dynamic> getJson(String path) async {
    throw const ApiException(404, 'Not Found');
  }

  @override
  Future<dynamic> postJson(String path, {Object? body}) async {
    throw UnimplementedError();
  }
}
