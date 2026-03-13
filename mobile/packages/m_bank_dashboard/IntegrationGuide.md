# m_bank_dashboard Integration Guide

## 1. Register a repository in DI

The package expects an implementation of `DashboardRepository`.

Example with the existing HackathonBank host app:

```dart
final apiService = BankApiService();
final dashboardRepository = BankApiDashboardRepository(apiService: apiService);
```

Example with `get_it`:

```dart
final getIt = GetIt.instance;

getIt.registerLazySingleton<BankApiService>(() => BankApiService());
getIt.registerLazySingleton<DashboardRepository>(
  () => BankApiDashboardRepository(apiService: getIt<BankApiService>()),
);
```

Example with a future MBank integration:

```dart
final existingClient = ExistingMbankClientImpl();
final dashboardRepository = MbankAdapter(client: existingClient);
```

## 2. Render the dashboard screen

```dart
AiDashboardScreen(
  repository: dashboardRepository,
  refreshSignal: refreshSignal,
  onDataChanged: _handleDataChanged,
)
```

## 3. Host responsibilities

- Provide a `DashboardRepository` implementation.
- Own app-level theme and navigation.
- React to `onDataChanged` to refresh related host screens.

## 4. Adapter guidance

- Use `BankApiDashboardRepository` when your backend already matches the HackathonBank endpoints.
- Use `MbankAdapter` as a template when embedding the package into an existing MBank client with different DTOs.
- Complete all `TODO` mappings in `MbankAdapter` before enabling dashboard features in production.
