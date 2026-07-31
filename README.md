# Tân Ân Portal Mobile

Flutter client for the Tân An SCADA read-only API. The app does not generate
demo telemetry: unavailable sources are shown as empty/error states until the
backend receives a real bridge snapshot.

## API configuration

The default API origin is:

```text
https://tanan.svnagentic.site
```

Override it at build or run time:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.20:3000
```

Use the LAN IP of the computer running Next.js when testing on a physical
phone. `localhost` on a phone points to the phone itself. For the Android
emulator, use `http://10.0.2.2:3000`.

The app reads:

- `GET /api/health`
- `GET /api/realtime/diagram`
- `GET /api/realtime/turbines`
- `GET /api/analytics/overview`
- `GET /api/analytics/trend`
- `GET /api/wind/forecast`

It never calls the bridge-only snapshot `POST` endpoints and does not include
the ingest key.

## Verification

```bash
flutter pub get
flutter analyze
flutter test
```
