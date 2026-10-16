import 'package:flutter_test/flutter_test.dart';
import 'package:shoplive_onboarding_demo/demo/data/qr_credentials.dart';

/// The QR format of the native test apps (ak / ck / title / userjwt) plus `st`.
void main() {
  test('native test-app QR: ak + ck + title', () {
    final qr = QrCredentials.parse('https://dev.shoplive.cloud/qr?ak=AK123&ck=CK456&title=My%20Live')!;
    expect(qr.accessKey, 'AK123');
    expect(qr.campaignKey, 'CK456');
    expect(qr.title, 'My Live');
    expect(qr.filledFields, ['accessKey', 'campaignKey']);
  });

  test('scheme, host and path are ignored', () {
    expect(QrCredentials.parse('shoplive://x/y?ck=C&ak=A')?.hasKeyPair, isTrue);
  });

  test('ak without ck (or ck without ak) is not used', () {
    expect(QrCredentials.parse('https://a.b/?ak=A'), isNull);
    final qr = QrCredentials.parse('https://a.b/?ck=C&st=TOKEN')!;
    expect(qr.hasKeyPair, isFalse);
    expect(qr.streamToken, 'TOKEN');
  });

  test('userjwt alone is accepted (PlayerDemo2)', () {
    expect(QrCredentials.parse('https://a.b/?userjwt=eyJ.x.y')?.userJwt, 'eyJ.x.y');
  });

  test('stream token key st', () {
    final qr = QrCredentials.parse('https://a.b/?ak=A&ck=C&st=eyJst')!;
    expect(qr.filledFields, ['accessKey', 'campaignKey', 'streamToken']);
  });

  test('blank, non-URL and keyless input is rejected', () {
    for (final raw in [null, '', '   ', 'hello world', 'https://a.b/', 'https://a.b/?ak=&ck=', 'https://a.b/?x=1']) {
      expect(QrCredentials.parse(raw), isNull, reason: '$raw');
    }
  });

  test('values are trimmed and percent-decoded', () {
    final qr = QrCredentials.parse(' https://a.b/?ak=%20A%20&ck=C ')!;
    expect(qr.accessKey, 'A');
  });
}
