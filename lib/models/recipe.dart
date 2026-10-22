import 'dart:convert';

/// A single instruction step, optionally with a photo.
class RecipeStep {
  String text;
  String? photo; // "asset:..." or a file name inside the app's photo folder

  RecipeStep(this.text, {this.photo});

  Map<String, dynamic> toJson() => {'text': text, if (photo != null) 'photo': photo};
  factory RecipeStep.fromJson(dynamic j) {
    if (j is String) return RecipeStep(j);
    return RecipeStep(j['text'] ?? '', photo: j['photo']);
  }
}

class Recipe {
  String id;
  String title;
  String description;
  String author; // who wrote/created the recipe
  String source; // e.g. "Wikibooks Cookbook", "Grandma's card box", website name
  String sourceUrl;
  String license; // license / credit line for text
  String collection; // family | friend | internet
  int servings;
  String yieldText;
  int prepMinutes;
  int cookMinutes;
  List<String> ingredients; // lines; a line starting with "#" is a section header
  List<RecipeStep> steps;
  String? photo; // hero photo of the finished dish
  String photoCredit;
  List<String> cuisines;
  List<String> mealTypes;
  List<String> seasons;
  List<String> holidays;
  List<String> keywords;
  String notes;
  String myNotes; // the user's own notes, kept even when the built-in library updates
  bool favorite;
  bool builtIn;
  int createdAt;
  int updatedAt;

  Recipe({
    required this.id,
    required this.title,
    this.description = '',
    this.author = '',
    this.source = '',
    this.sourceUrl = '',
    this.license = '',
    this.collection = 'family',
    this.servings = 4,
    this.yieldText = '',
    this.prepMinutes = 0,
    this.cookMinutes = 0,
    List<String>? ingredients,
    List<RecipeStep>? steps,
    this.photo,
    this.photoCredit = '',
    List<String>? cuisines,
    List<String>? mealTypes,
    List<String>? seasons,
    List<String>? holidays,
    List<String>? keywords,
    this.notes = '',
    this.myNotes = '',
    this.favorite = false,
    this.builtIn = false,
    int? createdAt,
    int? updatedAt,
  })  : ingredients = ingredients ?? [],
        steps = steps ?? [],
        cuisines = cuisines ?? [],
        mealTypes = mealTypes ?? [],
        seasons = seasons ?? [],
        holidays = holidays ?? [],
        keywords = keywords ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  int get totalMinutes => prepMinutes + cookMinutes;

  /// All photos referenced by the recipe (hero + step photos).
  List<String> get allPhotos => [
        ?photo,
        for (final s in steps)
          if (s.photo != null) s.photo!,
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'author': author,
        'source': source,
        'sourceUrl': sourceUrl,
        'license': license,
        'collection': collection,
        'servings': servings,
        'yieldText': yieldText,
        'prepMinutes': prepMinutes,
        'cookMinutes': cookMinutes,
        'ingredients': ingredients,
        'steps': steps.map((s) => s.toJson()).toList(),
        'photo': photo,
        'photoCredit': photoCredit,
        'cuisines': cuisines,
        'mealTypes': mealTypes,
        'seasons': seasons,
        'holidays': holidays,
        'keywords': keywords,
        'notes': notes,
        'myNotes': myNotes,
        'favorite': favorite,
        'builtIn': builtIn,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  static List<String> _strings(dynamic v) =>
      v == null ? <String>[] : (v as List).map((e) => e.toString()).toList();

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'],
        title: j['title'] ?? 'Untitled',
        description: j['description'] ?? '',
        author: j['author'] ?? '',
        source: j['source'] ?? '',
        sourceUrl: j['sourceUrl'] ?? '',
        license: j['license'] ?? '',
        collection: j['collection'] ?? 'family',
        servings: (j['servings'] as num?)?.toInt() ?? 4,
        yieldText: j['yieldText'] ?? '',
        prepMinutes: (j['prepMinutes'] as num?)?.toInt() ?? 0,
        cookMinutes: (j['cookMinutes'] as num?)?.toInt() ?? 0,
        ingredients: _strings(j['ingredients']),
        steps: ((j['steps'] as List?) ?? []).map(RecipeStep.fromJson).toList(),
        photo: j['photo'],
        photoCredit: j['photoCredit'] ?? '',
        cuisines: _strings(j['cuisines']),
        mealTypes: _strings(j['mealTypes']),
        seasons: _strings(j['seasons']),
        holidays: _strings(j['holidays']),
        keywords: _strings(j['keywords']),
        notes: j['notes'] ?? '',
        myNotes: j['myNotes'] ?? '',
        favorite: j['favorite'] ?? false,
        builtIn: j['builtIn'] ?? false,
        createdAt: (j['createdAt'] as num?)?.toInt(),
        updatedAt: (j['updatedAt'] as num?)?.toInt(),
      );

  Recipe copy() => Recipe.fromJson(jsonDecode(jsonEncode(toJson())));

  /// Lower-cased text blob used for fast free-text search.
  String? _searchBlob;
  String get searchBlob => _searchBlob ??= [
        title,
        description,
        author,
        source,
        ...keywords,
        myNotes,
        ...ingredients,
        ...cuisines,
        ...mealTypes,
        ...seasons,
        ...holidays,
      ].join(' \u0001 ').toLowerCase();
  void invalidateSearch() => _searchBlob = null;
}

String formatMinutes(int m) {
  if (m <= 0) return '—';
  if (m < 60) return '$m min';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '$h hr' : '$h hr $r min';
}
