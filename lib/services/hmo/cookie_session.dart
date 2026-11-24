import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The answer to one [CookieSession.request].
class SessionResponse {
  final int status;
  final Uri url;

  /// Status codes of any redirects that were followed, in order.
  final List<int> redirects;
  final String body;
  const SessionResponse(this.status, this.url, this.redirects, this.body);
}

/// Minimal HTTP client with a cookie jar. The HMO portals keep you logged in
/// with session cookies (ASP.NET_SessionId, laravel_session, ...) and set some
/// of them on redirect responses, so redirects are followed by hand to keep
/// every Set-Cookie. Port of functions/src/hmo/http.ts.
class CookieSession {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0 Mobile Safari/537.36';
  static const _maxRedirects = 5;
  static const _timeout = Duration(seconds: 25);

  final HttpClient _client = HttpClient()..connectionTimeout = _timeout;

  /// host -> cookie name -> value. Paths and expiry are ignored; fine for one
  /// portal per session.
  final Map<String, Map<String, String>> _jar = {};

  void _store(Uri url, HttpClientResponse res) {
    final lines = res.headers['set-cookie'];
    if (lines == null || lines.isEmpty) return;
    final host = _jar.putIfAbsent(url.host, () => {});
    for (final line in lines) {
      final parts = line.split(';');
      final pair = parts.first;
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final name = pair.substring(0, eq).trim();
      final value = pair.substring(eq + 1).trim();
      var expired = false;
      for (final a in parts.skip(1)) {
        final i = a.indexOf('=');
        if (i < 0) continue;
        final k = a.substring(0, i).trim().toLowerCase();
        final v = a.substring(i + 1).trim();
        if (k == 'max-age' && (int.tryParse(v) ?? 1) <= 0) expired = true;
        if (k == 'expires') {
          try {
            if (HttpDate.parse(v).isBefore(DateTime.now())) expired = true;
          } catch (_) {}
        }
      }
      if (expired || value.isEmpty) {
        host.remove(name);
      } else {
        host[name] = value;
      }
    }
  }

  String _cookieHeader(Uri url) {
    final host = _jar[url.host];
    if (host == null) return '';
    return host.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<SessionResponse> request(
    String method,
    String url, {
    Map<String, String>? query,
    Map<String, String>? form,
    Map<String, String>? headers,
  }) async {
    var target = Uri.parse(url);
    if (query != null) {
      target = target.replace(
        queryParameters: {...target.queryParameters, ...query},
      );
    }
    String? body = form == null ? null : Uri(queryParameters: form).query;
    final redirects = <int>[];

    while (true) {
      final HttpClientResponse res;
      try {
        final req = await _client.openUrl(method, target).timeout(_timeout);
        req.followRedirects = false;
        req.headers.set(HttpHeaders.userAgentHeader, _ua);
        headers?.forEach(req.headers.set);
        final cookie = _cookieHeader(target);
        if (cookie.isNotEmpty) {
          req.headers.set(HttpHeaders.cookieHeader, cookie);
        }
        if (body != null) {
          req.headers.contentType = ContentType(
            'application',
            'x-www-form-urlencoded',
            charset: 'utf-8',
          );
          req.write(body);
        }
        res = await req.close().timeout(_timeout);
      } on TimeoutException {
        throw HttpException('Timed out reaching ${target.host}');
      } on SocketException catch (e) {
        throw HttpException('Could not reach ${target.host}: ${e.message}');
      }
      _store(target, res);

      final loc = res.headers.value(HttpHeaders.locationHeader);
      if (res.statusCode >= 300 &&
          res.statusCode < 400 &&
          loc != null &&
          redirects.length < _maxRedirects) {
        redirects.add(res.statusCode);
        await res.drain<void>();
        target = target.resolve(loc);
        // Browsers switch to GET after 301/302/303.
        if (res.statusCode != 307 && res.statusCode != 308) {
          method = 'GET';
          body = null;
        }
        continue;
      }
      final text = await res
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout, onTimeout: () => '');
      return SessionResponse(res.statusCode, target, redirects, text);
    }
  }

  void close() => _client.close(force: true);
}

/// JSON-decodes [text], or returns null if it is not JSON.
Object? tryJson(String text) {
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}
