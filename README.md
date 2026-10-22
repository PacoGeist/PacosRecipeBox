# Recipe Box

A free, offline cookbook app for Android phones and tablets (iOS-ready), by **PacoGeist**.
Everything is stored on the device: no account, no ads, no tracking. Not for sale.

## Features

- **Opening screen** that looks like a cloth-bound cookbook with a table full of dishes on the cover.
- **Home page buttons:** Menu Planner, Grocery List, Menu History, All My Lists, My & Family Recipes, Friends' Recipes, Internet Recipes, Favorites, Cuisines, Seasonal (by season and by holiday), By Author, All Recipes, and one button for each meal type (Breakfast, Appetizers, Entrees, Side Dishes, Soups & Salads, Breads, Desserts, Beverages).
- **Cuisines:** American, Mexican, Japanese, Chinese, British, Irish, German, Indian, Native American, BBQ, Slow Cooker and Potluck. The built-in library has 50 recipes in each, 580 recipes in all, each one credited to its author and source.
- **Recipe pages** open with the photo of the finished dish. They show prep, cook and total time and the number of servings. The **½× 1× 2× 3×** buttons rescale every ingredient amount at once. You can check off ingredients as you go, and steps can have photos.
- **Cuisine, season and holiday pages** show one button per meal type (plus Favorites and All) instead of one long list. Recipe lists put your favorites at the top, and "Favorites first" is the default sort.
- **Make every recipe your own:** edit any recipe, including the built-in ones, and keep your own notes on it. Tap **I made this** to record the day you cooked it.
- **Menu Planner:** pick several recipes for a day, tick off each dish as you make it, and add a note for the day. Every recipe page also has an **Add to menu** button.
- **Menu History:** a calendar that shows what was planned and what you cooked on each day.
- **Grocery lists:** turn a day's menu, or any single recipe, into a shopping list. Items are grouped by department: Produce, Meat & Seafood, Dairy & Eggs, Bakery, Dry Goods & Canned (anything canned counts as dry goods), and Frozen. Checked items move to an "In the cart" section at the bottom. The Grocery List button on the home page opens your latest list, and you can type in extra items, change an item's department or share the list as text.
- **Search** by name, keyword, author or ingredient, and filter by cuisine, meal type, season, holiday, collection, total time or favorites.
- **Add your own recipes** with photos taken with the camera or picked from the gallery, for the finished dish and for each step.
- **Import from the web:** paste the link to a recipe page and the app reads the recipe, its photo and its author. This works with most recipe sites, which publish their recipes in the standard schema.org format.
- **Share** a recipe in any of these ways:
  - as a PDF recipe card by email or text
  - printed
  - as plain text
  - as a photo plus text for Facebook
  - as a `.recipe` file that another Recipe Box user can open, photos included. It lands in their Friends' Recipes.
- **Back up and restore** all your recipes, photos, favorites, notes, menus and grocery lists as one file. You can save it to the device, Google Drive or email.
- **Settings:**
  - light, dark or automatic mode
  - colors for the accent, background, cards (foreground), borders and text
  - five fonts
  - recipe text size and whole-app text size
  - an About page with the version number and credits
- **Update button:** it checks this GitHub repository's Releases page, downloads the newest APK and installs it over the old one. Your recipes are kept.

## Install on an Android phone or tablet

1. On the phone, open the **Releases** page of this repository and download the newest `RecipeBox-vX.Y.Z.apk`.
2. Open the downloaded file. If Android asks, allow your browser to **install unknown apps**.
3. Tap **Install**.

Later, tap **Settings ▸ Check for updates** in the app. The first time you do, Android asks you to let Recipe Box install apps.

## Publishing a new version (with GitHub Desktop)

1. Change `version:` in `pubspec.yaml`, for example `1.0.1+2`. The number after `+` must go up every time.
2. In GitHub Desktop, **Commit to main**, then **Push origin**.
   - The iPhone/iPad web app updates by itself: `.github/workflows/web.yml` rebuilds it and publishes it to GitHub Pages.
3. To publish a new Android version, in GitHub Desktop open **History**, right-click your latest commit, choose **Create Tag…**, enter `v1.0.1` (matching the version), then click **Push origin** again.
   - `.github/workflows/release.yml` builds the signed APK and attaches it to a new Release. Every installed copy will see the update when someone taps **Check for updates**.

### One-time setup: signing secrets

Android only installs an update if it is signed with the **same key** as the installed app. Keep `recipebox-release.jks` and its password somewhere safe, such as a password manager, and **never commit them**. They are already in `.gitignore`.

In GitHub, open **Settings ▸ Secrets and variables ▸ Actions** and add these four secrets:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the keystore file encoded as base64. In PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("recipebox-release.jks"))` |
| `ANDROID_KEYSTORE_PASSWORD` | the store password from `key.properties` |
| `ANDROID_KEY_ALIAS` | `recipebox` |
| `ANDROID_KEY_PASSWORD` | the key password from `key.properties` |

If the repository is not named `PacoGeist/PacosRecipeBox`, change `githubOwner` and `githubRepo` in `lib/services/update_service.dart`.

## Building on your own computer

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel) and Android Studio or the Android command-line tools.

```
flutter pub get
flutter test
flutter build apk --release --target-platform android-arm,android-arm64
```

The APK is saved to `build/app/outputs/flutter-apk/app-release.apk`. A local release build signs the APK with your key when `android/key.properties` is present.

## iPhone and iPad (web app)

The iPhone/iPad version is a **progressive web app** built from the same code. It installs from Safari, needs no App Store, and works offline once installed.

**Address:** https://pacogeist.github.io/PacosRecipeBox/

**Install:** open the address in **Safari**, tap **Share** (the square with the arrow), choose **Add to Home Screen**, then tap **Add**. Open it from the new Home Screen icon. The first launch downloads the recipe library and photos (about 50 MB), so use Wi-Fi for that.

**Your recipes** are saved on the device, inside the web app. Use **Settings ▸ Back up all my recipes** now and then, because deleting the web app from the Home Screen also deletes its data.

**Updates:** they arrive automatically the next time the app is opened online. **Settings ▸ Check for updates** also works.

**One-time setup:** in the repository, open **Settings ▸ Pages ▸ Build and deployment ▸ Source** and choose **GitHub Actions**. After that, every push publishes the web app.

### Importing recipes from websites in the web app

Browsers don't let a web app read other websites directly. To make **Import from a website** work in the iPhone version, set up a free "import helper":

1. Create a free Cloudflare account at https://dash.cloudflare.com, then go to **Workers & Pages ▸ Create ▸ Worker** and name it `recipe-helper`. Click **Deploy**.
2. Click **Edit code**, replace everything with the contents of `tool/web_import_helper/worker.js`, and click **Deploy**.
3. Copy the worker's address, for example `https://recipe-helper.yourname.workers.dev`, into the app at **Settings ▸ Web import helper**.

The Android app doesn't need the helper.

## Credits and licenses

- **Recipes from the Wikibooks Cookbook** (en.wikibooks.org/wiki/Cookbook) are by its contributors and licensed **CC BY-SA 4.0**. They have been reformatted for the app, and each one links back to its source page.
- **Recipe Box Kitchen recipes** are originals written for this app.
- **Photos** come from Wikimedia Commons and Flickr contributors (found through Openverse) under Creative Commons or public-domain licenses. Each recipe page lists its photo's author and license.
- **Ingredient illustrations** are [Twemoji](https://github.com/jdecked/twemoji), licensed CC BY 4.0.
- **Cover table texture** is "Wood planks" by Amal Kumar via Poly Haven, CC0.
- **Fonts** are Nunito, Lora, Playfair Display, Atkinson Hyperlegible and Caveat, all under the SIL Open Font License.
- **Recipes imported from websites** remain the property of their authors and are for personal use.
