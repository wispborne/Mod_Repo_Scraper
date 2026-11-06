import 'dart:io';

import 'package:mod_repo_scraper/manager/config_file_editor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const original = '# A note about the limit.\n'
      'llm_max_topics = 100\n'
      '\n'
      '# Where to send requests.\n'
      'llm_base_url=http://localhost:8080/v1\n'
      'qb_delay_ms = 1000\n';

  test('a key already set keeps its line and its "key = " part', () {
    final edited =
        ConfigFileEditor.edit(original, set: {'llm_max_topics': '300'});
    expect(edited, original.replaceFirst('= 100', '= 300'));

    final tight = ConfigFileEditor.edit(original,
        set: {'llm_base_url': 'http://127.0.0.1:8080/v1'});
    expect(tight, contains('\nllm_base_url=http://127.0.0.1:8080/v1\n'));
  });

  test('a reset key loses its line and nothing else changes', () {
    final edited = ConfigFileEditor.edit(original, remove: {'qb_delay_ms'});
    expect(edited, original.replaceFirst('qb_delay_ms = 1000\n', ''));
  });

  test('a new key goes at the end under one comment, added once', () {
    final once =
        ConfigFileEditor.edit(original, set: {'llm_summaries': 'true'});
    expect(once,
        '$original\n${ConfigFileEditor.marker}\nllm_summaries = true\n');

    final twice = ConfigFileEditor.edit(once, set: {'llm_model': 'qwen'});
    expect(ConfigFileEditor.marker.allMatches(twice).length, 1);
    expect(twice, endsWith('llm_summaries = true\nllm_model = qwen\n'));
  });

  test("the file's own line endings are kept", () {
    final windows = original.replaceAll('\n', '\r\n');
    final edited = ConfigFileEditor.edit(windows,
        set: {'llm_max_topics': '300', 'llm_summaries': 'true'});
    expect(edited.replaceAll('\r\n', ''), isNot(contains('\n')));
    expect(edited, contains('llm_max_topics = 300\r\n'));
    expect(edited, endsWith('llm_summaries = true\r\n'));
  });

  test('a key written twice has every copy changed', () {
    const doubled = 'llm_model = a\nllm_model = b\n';
    expect(ConfigFileEditor.edit(doubled, set: {'llm_model': 'c'}),
        'llm_model = c\nllm_model = c\n');
  });

  test('a commented-out key is left alone', () {
    const text = '# llm_model = old\nllm_model = a\n';
    expect(ConfigFileEditor.edit(text, set: {'llm_model': 'b'}),
        '# llm_model = old\nllm_model = b\n');
    expect(ConfigFileEditor.edit(text, remove: {'llm_model'}),
        '# llm_model = old\n');
  });

  test('an emptied value leaves "key =" with no space after it', () {
    expect(
        ConfigFileEditor.edit('llm_api_token = secret\n',
            set: {'llm_api_token': ''}),
        'llm_api_token =\n');
  });

  test('saving goes through a temporary file that then replaces the file',
      () async {
    final dir = await Directory.systemTemp.createTemp('config-editor-test');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'config.properties');
    File(path).writeAsStringSync(original);

    await ConfigFileEditor.save(path,
        set: {'llm_max_topics': '300'}, remove: {'qb_delay_ms'});

    expect(File(path).readAsStringSync(),
        original
            .replaceFirst('= 100', '= 300')
            .replaceFirst('qb_delay_ms = 1000\n', ''));
    expect(File('$path.tmp').existsSync(), isFalse);
    expect(dir.listSync().length, 1);
  });
}
