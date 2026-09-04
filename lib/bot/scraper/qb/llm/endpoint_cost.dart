/// Whether an LLM endpoint charges per token.
///
/// Worked out from the endpoint's address and model name alone — no network
/// call, no price table, no config key of its own. It exists so the fallback
/// can refuse to turn a free run into a paid one; see [FallbackLlmClient].
enum EndpointCost { free, paid }

/// Whether the endpoint at [baseUrl] running [model] costs money.
///
/// Free means one of two things:
/// - **The host is a machine you own.** Loopback, the three private IPv4
///   ranges, and `.local` names. A home LLM box is often another PC on the
///   network rather than `127.0.0.1`, so the whole private range counts — read
///   as paid, it would gate the switch for exactly the setup the fallback was
///   built for.
/// - **The model name ends in `:free`.** OpenRouter's own mark for a model it
///   does not charge for, and the only thing that tells a free OpenRouter model
///   from a paid one, since the address is the same either way.
///
/// Everything else is paid, an address that will not parse included: guessing
/// "free" is the answer that spends money.
EndpointCost endpointCost({required String baseUrl, required String model}) {
  if (_modelIsFree(model)) return EndpointCost.free;
  final uri = Uri.tryParse(baseUrl);
  if (uri == null) return EndpointCost.paid;
  return _hostIsOurs(uri.host) ? EndpointCost.free : EndpointCost.paid;
}

bool _modelIsFree(String model) =>
    model.trim().toLowerCase().endsWith(':free');

/// True for a host on a machine the operator owns, so tokens cost nothing.
bool _hostIsOurs(String rawHost) {
  final host = rawHost.trim().toLowerCase();
  if (host.isEmpty) return false;

  // Named loopback, and the IPv6 and all-interfaces spellings of it.
  if (host == 'localhost' || host.endsWith('.localhost')) return true;
  if (host == '::1' || host == '0.0.0.0') return true;

  // mDNS names, which only resolve on the local network.
  if (host == 'local' || host.endsWith('.local')) return true;

  final octets = host.split('.');
  if (octets.length != 4) return false;
  final numbers = octets.map(int.tryParse).toList();
  if (numbers.any((n) => n == null || n < 0 || n > 255)) return false;
  final first = numbers[0]!;
  final second = numbers[1]!;

  if (first == 127) return true; // 127.0.0.0/8, loopback
  if (first == 10) return true; // 10.0.0.0/8
  if (first == 192 && second == 168) return true; // 192.168.0.0/16
  if (first == 172 && second >= 16 && second <= 31) return true; // 172.16/12
  return false;
}
