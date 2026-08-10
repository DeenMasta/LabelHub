import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/printing/network_thermal_printer.dart';
import 'package:labelhub/core/printing/thermal_pdf_rasterizer.dart';

void main() {
  test('round-trips a network printer endpoint from its device identifier', () {
    final endpoint = NetworkPrinterEndpoint.fromDeviceId(
      NetworkPrinterEndpoint.deviceId(host: 'printer.local', port: 9100),
    );

    expect(endpoint.host, 'printer.local');
    expect(endpoint.port, 9100);
  });

  test('rejects an unusable network printer endpoint', () {
    expect(
      () => NetworkPrinterEndpoint.fromDeviceId('network:printer.local:0'),
      throwsA(isA<ThermalPrintingException>()),
    );
  });
}
