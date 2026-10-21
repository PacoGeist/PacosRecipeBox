# Recipe library curation brief

You are curating the built-in recipe library for "Recipe Box", a free offline cookbook app.
Each cuisine needs **exactly 50 recipes**. Recipes come from two sources:

1. **Wikibooks Cookbook** pages (CC BY-SA, already downloaded and parsed).
2. **Original recipes you write** ("Recipe Box Kitchen") ONLY to fill the gap when there are not 50 good Wikibooks recipes.

## Inputs (read with Python/jq; files are large, don't cat them whole)
- `/home/claude/seed/cand/<Cuisine>.json` — ranked candidates for the cuisine (best first). Fields: page, title, hasPhoto, wbCats, guessMeal, servings, prep, cook, first 8 ingredients, nIngredients, nSteps, description.
- `/home/claude/seed/classified.json` — dict page -> full parsed recipe (title, ingredients, steps, cats, description, image, ...) for ALL ~3,600 Wikibooks recipes. Search it (e.g. by title keywords) if the candidate list is short or noisy — good recipes are sometimes missed by the classifier.

## Selection rules for Wikibooks recipes
- Must truly belong to the cuisine (e.g. "Tortilla Española" is Spanish, NOT Mexican; "Bánh Mì" is Vietnamese, not Japanese). For BBQ: grilled/smoked/barbecued dishes, BBQ sauces/rubs are OK but keep them to a few. For Slow Cooker: recipes actually cooked in a slow cooker / crock pot. For Potluck: crowd-friendly dishes people bring to gatherings (casseroles, dips, salads, baked beans, bars, brownies, cookies, deviled eggs, sheet cakes, punch...). For American: classic US dishes, regional US cooking.
- Prefer: recipes with photos (hasPhoto), well-known classic dishes, complete ingredient lists with amounts, clear steps, a good spread of meal types (breakfast, appetizers, entrees, sides, soups & salads, breads, desserts, beverages).
- Avoid: near-duplicates (pick the best of "Guacamole I/II/III"), joke/odd entries, pure condiments unless iconic, recipes with very vague ingredients, anything not in English, offensive titles (e.g. skip "Atomic Buffalo Turds").
- A recipe may appear in more than one cuisine (that's fine), but keep each cuisine's 50 distinct.

## Original recipes (only if needed to reach 50)
Write classic, authentic, well-tested-style recipes a home cook would recognize. Be accurate: realistic amounts, temperatures (°F with °C in parentheses), and times. US measures (cups, tbsp, tsp, oz, lb). Ingredient lines MUST start with the amount so the app can scale them ("2 cups flour", "1 1/2 tsp salt", "3 eggs"); use "# For the sauce" lines for sub-headings when useful. 5–14 steps, each a full sentence. Don't duplicate a dish already selected from Wikibooks.

## Output
Write `/home/claude/seed/curated/<Cuisine>.json` (cuisine name with spaces replaced by underscores) as:
```json
{
  "cuisine": "Irish",
  "selected": [
    {"page": "Cookbook:Colcannon", "mealTypes": ["Side Dish"], "seasons": ["Fall","Winter"], "holidays": ["St. Patrick's Day","Halloween"], "keywords": ["potato","cabbage"]}
  ],
  "original": [
    {"title": "Irish Brown Bread", "description": "1–2 sentence description.", "servings": 10, "prepMinutes": 10, "cookMinutes": 45,
     "ingredients": ["2 cups whole wheat flour", "..."], "steps": ["Preheat the oven to 400°F (200°C).", "..."],
     "mealTypes": ["Bread"], "seasons": [], "holidays": ["St. Patrick's Day"], "keywords": ["brown bread","soda bread"],
     "photoQuery": "Irish brown soda bread"}
  ]
}
```
- len(selected) + len(original) must equal 50.
- mealTypes values: Breakfast, Appetizer, Entree, Side Dish, Soup & Salad, Bread, Dessert, Beverage (1–2 each; sauces/condiments → "Side Dish").
- seasons values: Spring, Summer, Fall, Winter (only when the dish is clearly seasonal; can be empty).
- holidays values (only when traditional/clearly fitting): New Year's, Lunar New Year, Valentine's Day, St. Patrick's Day, Easter, Passover, Cinco de Mayo, Fourth of July, Oktoberfest, Halloween, Diwali, Thanksgiving, Hanukkah, Christmas, Game Day.
- keywords: 2–5 lowercase helpful search words (main ingredient, style, e.g. "spicy", "vegetarian", "grilled").
- photoQuery: a short, common English name of the dish for a Wikimedia Commons photo search.

Validate the JSON with Python (json.load) and the 50 count before finishing. Reply with a 3–5 line summary: how many Wikibooks vs original, and anything notable. Do not paste the recipes in your reply.
