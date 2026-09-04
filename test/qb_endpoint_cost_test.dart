import 'package:mod_repo_scraper/bot/scraper/qb/llm/endpoint_cost.dart';
import 'package:test/test.dart';

void main() {
  EndpointCost cost(String url, [String model = 'qwen3-32b']) =>
      endpointCost(baseUrl: url, model: model);

  group('endpointCost — free because the machine is ours', () {
    test('loopback by name', () {
      expect(cost('http://localhost:8080/v1/chat/completions'),
          EndpointCost.free);
    });
    test('loopback by address', () {
      expect(cost('http://127.0.0.1:8080/v1/chat/completions'),
          EndpointCost.free);
    });
    test('anywhere in 127.0.0.0/8', () {
      expect(cost('http://127.1.2.3:8080/v1/chat/completions'),
          EndpointCost.free);
    });
    test('the IPv6 loopback', () {
      expect(cost('http://[::1]:8080/v1/chat/completions'), EndpointCost.free);
    });
    test('all interfaces', () {
      expect(
          cost('http://0.0.0.0:8080/v1/chat/completions'), EndpointCost.free);
    });
    test('192.168.0.0/16', () {
      expect(cost('http://192.168.1.40:8080/v1/chat/completions'),
          EndpointCost.free);
    });
    test('10.0.0.0/8', () {
      expect(
          cost('http://10.7.3.9:8080/v1/chat/completions'), EndpointCost.free);
    });
    test('172.16.0.0/12, bottom of the range', () {
      expect(cost('http://172.16.0.1:8080/v1/chat/completions'),
          EndpointCost.free);
    });
    test('172.16.0.0/12, top of the range', () {
      expect(cost('http://172.31.255.254:8080/v1/chat/completions'),
          EndpointCost.free);
    });
    test('a .local name', () {
      expect(cost('http://workshop.local:8080/v1/chat/completions'),
          EndpointCost.free);
    });
    test('the port makes no difference', () {
      expect(cost('http://192.168.1.40/v1/chat/completions'),
          EndpointCost.free);
    });
  });

  group('endpointCost — just outside the private ranges is paid', () {
    // 172.15 and 172.32 sit either side of 172.16–172.31. Getting the edge
    // wrong here is the mistake that would read a real cloud host as free.
    test('172.15 is not private', () {
      expect(cost('http://172.15.0.1:8080/v1/chat/completions'),
          EndpointCost.paid);
    });
    test('172.32 is not private', () {
      expect(cost('http://172.32.0.1:8080/v1/chat/completions'),
          EndpointCost.paid);
    });
    test('192.167 is not private', () {
      expect(cost('http://192.167.1.1:8080/v1/chat/completions'),
          EndpointCost.paid);
    });
    test('11.x is not private', () {
      expect(
          cost('http://11.0.0.1:8080/v1/chat/completions'), EndpointCost.paid);
    });
    test('a host that merely starts like a private address', () {
      expect(cost('http://10.example.com/v1/chat/completions'),
          EndpointCost.paid);
    });
    test('a host that merely contains "localhost"', () {
      expect(cost('https://localhost.example.com/v1/chat/completions'),
          EndpointCost.paid);
    });
    test('a host that merely contains ".local"', () {
      expect(cost('https://my.local.example.com/v1/chat/completions'),
          EndpointCost.paid);
    });
  });

  group('endpointCost — the model name can say free', () {
    test('an OpenRouter :free model', () {
      expect(
          cost('https://openrouter.ai/api/v1/chat/completions',
              'qwen/qwen3-235b-a22b:free'),
          EndpointCost.free);
    });
    test(':free is read whatever its capitals', () {
      expect(
          cost('https://openrouter.ai/api/v1/chat/completions',
              'Qwen/Qwen3-235B:FREE'),
          EndpointCost.free);
    });
    test('surrounding spaces do not hide it', () {
      expect(
          cost('https://openrouter.ai/api/v1/chat/completions',
              '  deepseek/deepseek-r1:free  '),
          EndpointCost.free);
    });
    test('a paid OpenRouter model at the same address', () {
      expect(
          cost('https://openrouter.ai/api/v1/chat/completions',
              'deepseek/deepseek-chat'),
          EndpointCost.paid);
    });
    test('"free" not at the end does not count', () {
      expect(
          cost('https://openrouter.ai/api/v1/chat/completions',
              'someone/free-model-v2'),
          EndpointCost.paid);
    });
  });

  group('endpointCost — anything else is paid', () {
    test('a public host with a local-sounding model', () {
      expect(cost('https://llm.example.com/v1/chat/completions', 'qwen3-32b'),
          EndpointCost.paid);
    });
    test('an address with no host at all', () {
      expect(cost('not a url'), EndpointCost.paid);
    });
    test('an empty address', () {
      expect(cost(''), EndpointCost.paid);
    });
  });
}
