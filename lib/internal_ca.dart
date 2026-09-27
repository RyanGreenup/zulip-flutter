import 'dart:convert';
import 'dart:io';

// mkcert root "mkcert user@vidar (User)", for `*.k8s.vidar`.
// SHA-256 4B:C1:1D:57:19:5B:AF:F8:49:F7:F1:9F:34:F0:7A:73:86:F6:E4:27:2E:AD:EF:CF:99:B8:FA:70:19:65:C2:C7
const _vidarRootCaPem = '''
-----BEGIN CERTIFICATE-----
MIIEjTCCAvWgAwIBAgIQMTLalPSJlK4gdEGH5eH19DANBgkqhkiG9w0BAQsFADBf
MR4wHAYDVQQKExVta2NlcnQgZGV2ZWxvcG1lbnQgQ0ExGjAYBgNVBAsMEXVzZXJA
dmlkYXIgKFVzZXIpMSEwHwYDVQQDDBhta2NlcnQgdXNlckB2aWRhciAoVXNlcikw
HhcNMjYwNDEyMTMyOTQ3WhcNMzYwNDEyMTMyOTQ3WjBfMR4wHAYDVQQKExVta2Nl
cnQgZGV2ZWxvcG1lbnQgQ0ExGjAYBgNVBAsMEXVzZXJAdmlkYXIgKFVzZXIpMSEw
HwYDVQQDDBhta2NlcnQgdXNlckB2aWRhciAoVXNlcikwggGiMA0GCSqGSIb3DQEB
AQUAA4IBjwAwggGKAoIBgQDgESJIqtSEiAtmc78gsMqhL+KpktU5Dz7ugn/C6fAn
h8LBTZ61cFz49hBm1T9i0HJQBxcMib67rBBl6YiakXz4ZXHGHwh/PyGCfa4q3Xoo
gCCGFXUCR7bo1e1JYolwx4mqtlPwS8bEg7zPtvZ4sqBADuxz00KDdGVj4+xmzQKi
aybjdxpUI2w6jIOYfacwpXP+Cj/rJprDbvx+g/29Q+YYdy40FNFDY4V1/3dNKePr
L9LaKVoZmU9gbOoMfg/eRYAWOGpg/PmfFnGz34H5DA5IJn5NNTGv8Ha82wNZjdry
xFnG+9Q8HRqKmhc4UZRQMFKtwmvYrXBXpfgJdN7OO3Hmol7hDNHfST+rQg2P9QX3
YXAXYEq50PV+tWvKRCGGztVnsLGJag3vO9cDa6lDYEg5NMiHZk4FmMHo+b4M+OZI
CW1Tm9iSToLbVp5hy1KEpwzjs1gnesp14MwfQNJZHa24Xb2W6qOJVi58UFs7iVKE
/LEMEBa3POWHKvkcLf/9EysCAwEAAaNFMEMwDgYDVR0PAQH/BAQDAgIEMBIGA1Ud
EwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFC8ylQlDMUamDGUk2uPpgHVRfqwjMA0G
CSqGSIb3DQEBCwUAA4IBgQAXVytaOr/hv7CbsbMc4QYJ89kVJtiPyA7uuak/fJML
Hp09eBk7bPVQUJShi5W1YI0Yr4dwFShckRlCH2L0QjG7KWUnUp40SFRqXmweKZyi
vdZnYokj+nLf/mWdxVq5UNPesaktVWokvvOW0oelGpqE9FWkHrv7wZPMG9cFmBu0
OBGNeQOcz9K7KFaKDJOXvVmqPYglkPbaigIWTX+HBKH+9SnanWNmxlULiErLdH9o
5eouhsnjGYQKDm8pSwhYFmbzidnn3nRnFXtGyjot0XNgLSV+ID84zjtY1146kIc0
NPVwBqctnQLvS+9n/ImowTAondeqPvmuONFHc2t9GYVX7yDpuzYSROWvdg0vt/nq
lC/0OLSoKScSzxEG5htNEwlNBDwUi933qSRRR90xyz+Ukk7hA4SxXlvv3s7RQ36h
ov2SCkAdnJCXH9O6VGUOKUPb9Qh5Ufzr4QlYl2sLV6RlvaqDVGGVpCzRKcu8ZCOK
GDMQMmQD0V9RC+6xQlTLufA=
-----END CERTIFICATE-----
''';

// mkcert root "mkcert ryan@vale", for `*.k8s.lan` and `*.k8s.local`.
// SHA-256 E4:C9:88:2C:77:30:B9:72:FD:64:5B:68:E0:15:90:3C:5C:E3:14:D1:35:B0:37:E9:75:59:50:26:3A:30:C8:7E
const _valeRootCaPem = '''
-----BEGIN CERTIFICATE-----
MIIEbTCCAtWgAwIBAgIQBzLKEdAFan78145zIxO8OTANBgkqhkiG9w0BAQsFADBP
MR4wHAYDVQQKExVta2NlcnQgZGV2ZWxvcG1lbnQgQ0ExEjAQBgNVBAsMCXJ5YW5A
dmFsZTEZMBcGA1UEAwwQbWtjZXJ0IHJ5YW5AdmFsZTAeFw0yNjAzMjQxNDM3Mzla
Fw0zNjAzMjQxNDM3MzlaME8xHjAcBgNVBAoTFW1rY2VydCBkZXZlbG9wbWVudCBD
QTESMBAGA1UECwwJcnlhbkB2YWxlMRkwFwYDVQQDDBBta2NlcnQgcnlhbkB2YWxl
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEApM8Lg2SMCG5OdS5Ik7ZP
kMe96mTkE9qzd3xmVWQ7OiRkSAJJORkMu1rEtJe3LdXWbjg/81GSDchyXDEk4Enw
GYbohDlxNiluEPi63+n7E8yfOZbhD3U8i35Zvh0bci4i49YebHiRQ4HAxPSTSkrO
rgx9qeP/jHvoB+LF3ptHCrcWIDnGCnqKyAtEV4MJ7gUhGjtDI/CwOcyho7wMmPks
0JixyL4VEPLZUHo6ve0RJd1GBrHnTJ1xBo0WNz9TrkUGMVvpQwVD7XQByGQslVWq
zlkuHfNo7t7rxVciNiod2FDojLiOHdASzSRaZQ5lYCBYs1dg1uizjYCYdMiOG7FA
jDCEYHnQQ+JLObwBZ3rmYGUtmJ8/T5sr2Bc5yMGICiFbwUUo1SO149nsK7Mw8RlG
51wWYHdTOZX0B9/64CMwUx1cu5Rr9HZxbC5YlX8AwzeYTbgc589RDRjKJHl15ogI
reaDs5h+dd/x6nucyLv30id4HGKQ8zJqpwlaTaql0Y7pAgMBAAGjRTBDMA4GA1Ud
DwEB/wQEAwICBDASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBQOxZOFV4Ik
VxkGZGwAgVBozScG+DANBgkqhkiG9w0BAQsFAAOCAYEAH1R4/WS7eYYvTPXQAVgO
mc1/LlzN66PhWgropU9XJmwoKs6o/6eH09g/f0/8J3YR2vwz0GoQwtX24xTWPdLP
64E68ePh0kp7INre1gBSsGMj+ck1rO4pv+U11XpTq5qmsdh3MwQPXAdmponS4wl7
ecdk/wknh3fMl9tKTO+qhdhhDm/Ix//yW0qMk1KJFW6sPapGjDG/S0TNasjyT462
6JPso+zcR94Pe/HwFUJnKBg1sc/pu6V2GJc4JM2s7kDvcu6Sb1xwSN8nkMEsB8nV
4sDS4m6zkHaEPqfhEu5y2R85yNfRYOTokNGM1UHl1ca13WeDt8UkvQSvlw/0DMTp
brnUybF9dk84cAIxBD603iihQEsaYzNDGgkm7SlfRyTWa01fJSr0rr18d7N3QYUb
Yoy5xX0bXkaM+In56sqJ4bJXfsygV21Z8TORKwMHcAemYINu99gzH0kqDgmLW3Nc
4zV4MluVMGvyWFOTq4cWeFYnRkYcbLoJOuyQd/2RgWCy
-----END CERTIFICATE-----
''';

/// A [SecurityContext] trusting the usual public roots
/// plus our homelab mkcert roots.
///
/// Keep the roots here in sync with
/// android/app/src/main/res/xml/network_security_config.xml ,
/// which covers native networking such as video playback.
SecurityContext internalCaSecurityContext() {
  return SecurityContext(withTrustedRoots: true)
    ..setTrustedCertificatesBytes(utf8.encode(_vidarRootCaPem))
    ..setTrustedCertificatesBytes(utf8.encode(_valeRootCaPem));
}

class _InternalCaHttpOverrides extends HttpOverrides {
  _InternalCaHttpOverrides(this._context);

  final SecurityContext _context;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context ?? _context);
  }
}

/// Make every [HttpClient] in this isolate trust [internalCaSecurityContext].
///
/// Dart's TLS on Android ignores user-installed CAs,
/// so this is what lets the app reach a server with an mkcert certificate.
/// It covers package:http clients and [Image.network] alike.
///
/// Call this in each isolate's entry point,
/// before any HTTP client is created.
void installInternalCaTrust() {
  HttpOverrides.global = _InternalCaHttpOverrides(internalCaSecurityContext());
}
