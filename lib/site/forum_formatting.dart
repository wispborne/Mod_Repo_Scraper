/// Read forum formatting into fixed size classes, checked colours and video ids.
library;

/// The four size steps a description can use, from the class names the site's
/// stylesheet knows. Ordinary text has no step.
enum SizeStep { small, big, bigger, biggest }

extension SizeStepClass on SizeStep {
  String get className => switch (this) {
        SizeStep.small => 'size-small',
        SizeStep.big => 'size-big',
        SizeStep.bigger => 'size-bigger',
        SizeStep.biggest => 'size-biggest',
      };
}

/// Named sizes, in points. These are the browser's own sizes, so "medium" is
/// 12pt, which is bigger than the forum's 10pt body text.
const Map<String, double> _namedSizes = {
  'xx-small': 6,
  'x-small': 7.5,
  'small': 9,
  'smaller': 10,
  'medium': 12,
  'large': 14,
  'larger': 14,
  'x-large': 18,
  'xx-large': 24,
};

final RegExp _sizeValue = RegExp(r'^(\d{1,3}(?:\.\d{1,3})?)\s*(pt|px|em)$');

/// The forum's body text, in points. Sizes are judged against this.
const double _forumBodyPoints = 10;

/// The size step for a CSS `font-size` value, or null for ordinary text or a
/// size that cannot be read. The forum's body text is 10pt, and each size goes
/// to the step whose size on the site is nearest in proportion to the body:
/// under 9.5pt small, 9.5 to 11 ordinary, 11 to 13 big, 13 to 17 bigger, 17 and
/// up biggest. So the forum's 12pt is big, 14pt is bigger and 18pt is biggest.
SizeStep? sizeStepOf(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == null || text.isEmpty) return null;

  double? points = _namedSizes[text];
  if (points == null) {
    final match = _sizeValue.firstMatch(text);
    if (match == null) return null;
    final number = double.parse(match[1]!);
    points = switch (match[2]) {
      'px' => number * 0.75,
      'em' => number * _forumBodyPoints,
      _ => number,
    };
  }
  if (points < 9.5) return SizeStep.small;
  if (points < 11) return null;
  if (points < 13) return SizeStep.big;
  if (points < 17) return SizeStep.bigger;
  return SizeStep.biggest;
}

final RegExp _longHex = RegExp(r'^#([0-9a-f]{6})$');
final RegExp _shortHex = RegExp(r'^#([0-9a-f]{3})$');
final RegExp _rgb =
    RegExp(r'^rgb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$');

/// A CSS `color` value as `#rrggbb`, or null when it is not one of the plain
/// forms the forum writes: a colour name, `#rgb`, `#rrggbb` or `rgb(r, g, b)`.
/// `transparent` is null, because a colour nobody can see is not one to keep.
String? hexColourOf(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == null || text.isEmpty) return null;

  final named = cssColourNames[text];
  if (named != null) return named;

  final long = _longHex.firstMatch(text);
  if (long != null) return '#${long[1]}';

  final short = _shortHex.firstMatch(text);
  if (short != null) {
    return '#${short[1]!.split('').map((digit) => '$digit$digit').join()}';
  }

  final rgb = _rgb.firstMatch(text);
  if (rgb != null) {
    final parts = [rgb[1], rgb[2], rgb[3]].map((v) => int.parse(v!)).toList();
    if (parts.any((v) => v > 255)) return null;
    return '#${parts.map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';
  }
  return null;
}

/// The forum's embeds name the video's host without a scheme
/// (`//www.youtube.com/embed/…`), and sometimes with one.
final RegExp _youTubeEmbed = RegExp(
  r'^(?:https?:)?//(?:www\.)?(?:youtube\.com|youtube-nocookie\.com)/embed/'
  r'([A-Za-z0-9_-]{11})(?:[?#&].*)?$',
);
final RegExp _vimeoEmbed =
    RegExp(r'^(?:https?:)?//player\.vimeo\.com/video/(\d{1,12})(?:[?#].*)?$');

/// The YouTube video id of an embed address, or null when it is not one.
String? youTubeIdOf(String? src) => _youTubeEmbed.firstMatch(src?.trim() ?? '')?[1];

/// The Vimeo video number of an embed address, or null when it is not one.
String? vimeoIdOf(String? src) => _vimeoEmbed.firstMatch(src?.trim() ?? '')?[1];

/// One declaration's value out of a `style` attribute, or null.
String? styleValue(String? style, String property) {
  if (style == null) return null;
  for (final declaration in style.split(';')) {
    final colon = declaration.indexOf(':');
    if (colon < 0) continue;
    if (declaration.substring(0, colon).trim().toLowerCase() == property) {
      return declaration.substring(colon + 1).trim();
    }
  }
  return null;
}

/// Every CSS colour name, as `#rrggbb`.
const Map<String, String> cssColourNames = {
  'aliceblue': '#f0f8ff', 'antiquewhite': '#faebd7', 'aqua': '#00ffff',
  'aquamarine': '#7fffd4', 'azure': '#f0ffff', 'beige': '#f5f5dc',
  'bisque': '#ffe4c4', 'black': '#000000', 'blanchedalmond': '#ffebcd',
  'blue': '#0000ff', 'blueviolet': '#8a2be2', 'brown': '#a52a2a',
  'burlywood': '#deb887', 'cadetblue': '#5f9ea0', 'chartreuse': '#7fff00',
  'chocolate': '#d2691e', 'coral': '#ff7f50', 'cornflowerblue': '#6495ed',
  'cornsilk': '#fff8dc', 'crimson': '#dc143c', 'cyan': '#00ffff',
  'darkblue': '#00008b', 'darkcyan': '#008b8b', 'darkgoldenrod': '#b8860b',
  'darkgray': '#a9a9a9', 'darkgreen': '#006400', 'darkgrey': '#a9a9a9',
  'darkkhaki': '#bdb76b', 'darkmagenta': '#8b008b',
  'darkolivegreen': '#556b2f', 'darkorange': '#ff8c00',
  'darkorchid': '#9932cc', 'darkred': '#8b0000', 'darksalmon': '#e9967a',
  'darkseagreen': '#8fbc8f', 'darkslateblue': '#483d8b',
  'darkslategray': '#2f4f4f', 'darkslategrey': '#2f4f4f',
  'darkturquoise': '#00ced1', 'darkviolet': '#9400d3', 'deeppink': '#ff1493',
  'deepskyblue': '#00bfff', 'dimgray': '#696969', 'dimgrey': '#696969',
  'dodgerblue': '#1e90ff', 'firebrick': '#b22222', 'floralwhite': '#fffaf0',
  'forestgreen': '#228b22', 'fuchsia': '#ff00ff', 'gainsboro': '#dcdcdc',
  'ghostwhite': '#f8f8ff', 'gold': '#ffd700', 'goldenrod': '#daa520',
  'gray': '#808080', 'green': '#008000', 'greenyellow': '#adff2f',
  'grey': '#808080', 'honeydew': '#f0fff0', 'hotpink': '#ff69b4',
  'indianred': '#cd5c5c', 'indigo': '#4b0082', 'ivory': '#fffff0',
  'khaki': '#f0e68c', 'lavender': '#e6e6fa', 'lavenderblush': '#fff0f5',
  'lawngreen': '#7cfc00', 'lemonchiffon': '#fffacd', 'lightblue': '#add8e6',
  'lightcoral': '#f08080', 'lightcyan': '#e0ffff',
  'lightgoldenrodyellow': '#fafad2', 'lightgray': '#d3d3d3',
  'lightgreen': '#90ee90', 'lightgrey': '#d3d3d3', 'lightpink': '#ffb6c1',
  'lightsalmon': '#ffa07a', 'lightseagreen': '#20b2aa',
  'lightskyblue': '#87cefa', 'lightslategray': '#778899',
  'lightslategrey': '#778899', 'lightsteelblue': '#b0c4de',
  'lightyellow': '#ffffe0', 'lime': '#00ff00', 'limegreen': '#32cd32',
  'linen': '#faf0e6', 'magenta': '#ff00ff', 'maroon': '#800000',
  'mediumaquamarine': '#66cdaa', 'mediumblue': '#0000cd',
  'mediumorchid': '#ba55d3', 'mediumpurple': '#9370db',
  'mediumseagreen': '#3cb371', 'mediumslateblue': '#7b68ee',
  'mediumspringgreen': '#00fa9a', 'mediumturquoise': '#48d1cc',
  'mediumvioletred': '#c71585', 'midnightblue': '#191970',
  'mintcream': '#f5fffa', 'mistyrose': '#ffe4e1', 'moccasin': '#ffe4b5',
  'navajowhite': '#ffdead', 'navy': '#000080', 'oldlace': '#fdf5e6',
  'olive': '#808000', 'olivedrab': '#6b8e23', 'orange': '#ffa500',
  'orangered': '#ff4500', 'orchid': '#da70d6', 'palegoldenrod': '#eee8aa',
  'palegreen': '#98fb98', 'paleturquoise': '#afeeee',
  'palevioletred': '#db7093', 'papayawhip': '#ffefd5',
  'peachpuff': '#ffdab9', 'peru': '#cd853f', 'pink': '#ffc0cb',
  'plum': '#dda0dd', 'powderblue': '#b0e0e6', 'purple': '#800080',
  'rebeccapurple': '#663399', 'red': '#ff0000', 'rosybrown': '#bc8f8f',
  'royalblue': '#4169e1', 'saddlebrown': '#8b4513', 'salmon': '#fa8072',
  'sandybrown': '#f4a460', 'seagreen': '#2e8b57', 'seashell': '#fff5ee',
  'sienna': '#a0522d', 'silver': '#c0c0c0', 'skyblue': '#87ceeb',
  'slateblue': '#6a5acd', 'slategray': '#708090', 'slategrey': '#708090',
  'snow': '#fffafa', 'springgreen': '#00ff7f', 'steelblue': '#4682b4',
  'tan': '#d2b48c', 'teal': '#008080', 'thistle': '#d8bfd8',
  'tomato': '#ff6347', 'turquoise': '#40e0d0', 'violet': '#ee82ee',
  'wheat': '#f5deb3', 'white': '#ffffff', 'whitesmoke': '#f5f5f5',
  'yellow': '#ffff00', 'yellowgreen': '#9acd32',
};
