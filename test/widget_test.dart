import 'package:flutter_test/flutter_test.dart';
import 'package:tan_an_portal/features/scada/data/models/scada_models.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';

void main() {
  group('SCADA Data Models & Helpers Unit Tests', () {
    test('ScadaTag parsing test', () {
      final jsonTag = {
        'value': 50.2393,
        'quality': 'GOOD',
        'quality_code': 192,
        'timestamp': '2026-07-22T02:41:38.000Z',
        'error': '0x00000000',
      };

      final tag = ScadaTag.fromJson(jsonTag);

      expect(tag.value, 50.2393);
      expect(tag.quality, 'GOOD');
      expect(tag.qualityCode, 192);
      expect(tag.timestamp, '2026-07-22T02:41:38.000Z');
      expect(tag.isGoodQuality, true);
    });

    test('ScadaSnapshot parsing test', () {
      final jsonSnapshot = {
        'source': 'test-source',
        'version': '1.0.0',
        'station': 'TANAN',
        'screen': 'ONELINE_1',
        'snapshot_utc': '2026-07-22T02:41:38.000Z',
        'read_only': true,
        'tags': {
          'Subs::Oneline::Hz': {
            'value': 50.2,
            'quality': 'GOOD',
            'quality_code': 192,
            'timestamp': '2026-07-22T02:41:38.000Z',
          },
          'E02::XSWI11::PosSt': {
            'value': 2,
            'quality': 'GOOD',
            'quality_code': 192,
            'timestamp': '2026-07-22T02:41:38.000Z',
          },
        },
      };

      final snapshot = ScadaSnapshot.fromJson(jsonSnapshot);

      expect(snapshot.source, 'test-source');
      expect(snapshot.tags.length, 2);
      expect(snapshot.tags['Subs::Oneline::Hz']?.value, 50.2);
    });

    test('ScadaHelpers calculation test', () {
      final jsonSnapshot = {
        'source': 'test',
        'tags': {
          'Subs::Oneline::Hz': {'value': 50.1, 'quality': 'GOOD'},
          'E01::XCBR1::PosSt': {
            'value': 2, // Closed
            'quality': 'GOOD',
          },
          'E02::XCBR1::PosSt': {
            'value': 1, // Open
            'quality': 'GOOD',
          },
          'E03::XCBR1::PosSt': {
            'value': 1,
            'quality': 'BAD', // Bad quality -> unknown
          },
        },
      };

      final snapshot = ScadaSnapshot.fromJson(jsonSnapshot);

      // Test readNumber
      expect(ScadaHelpers.readNumber(snapshot, 'Subs::Oneline::Hz'), 50.1);

      // Test readPositionState
      expect(
        ScadaHelpers.readPositionState(snapshot, 'E01::XCBR1::PosSt'),
        PositionState.closed,
      );
      expect(
        ScadaHelpers.readPositionState(snapshot, 'E02::XCBR1::PosSt'),
        PositionState.open,
      );
      expect(
        ScadaHelpers.readPositionState(snapshot, 'E03::XCBR1::PosSt'),
        PositionState.unknown,
      );

      // Test formatMeasurement
      expect(ScadaHelpers.formatMeasurement(50.123, 2), '50.12');
      expect(ScadaHelpers.formatMeasurement(null, 2), 'Mất kết nối');
    });
  });
}
