# Google Play listing: Crowd Cannon

Everything to paste into Play Console. Files are in this `store` folder.

## Main store listing

**App name** (30 max)
Crowd Cannon: Bloop's Battle

**Short description** (80 max)
Shoot, multiply your crowd through gates and smash the castle with Bloop!

**Full description** (4000 max)
Fire your cannon, multiply your army and overrun the enemy castle!

Hold to shoot and drag to aim. Send your crowd through + gates and the rare x2 and x3 gates to grow a huge army, dodge the sneaky ÷ traps, and crash into the red castle before their army gets through. Charge up your Champion to smash everything in its path, and face giant slimes, skeleton mini-bosses and dragon bosses.

Meet Bloop, your cheerful guide, who teaches you the ropes, cheers your wins and loves dressing up!

FEATURES
• Easy to learn, fun to master: one finger, quick levels
• Huge crowds of hundreds of runners on screen
• Unlock bigger cannons as you play: Twin Blaster, Triple Threat, Mega Cannon and the 4-barrel Titan
• Break barrels for a bigger cannon, while the red army keeps coming
• Roads that split, swing wide and cross: pick your road from level 15
• Gates, traps, giants, skeleton mini-bosses and 8 dragon boss fights
• 40 hand-made levels in 4 worlds: Meadow, Desert, Snow and Volcano, up to the Dragon King
• Level map with stars to collect on every level
• Dress up Bloop: party hats, crowns, wizard hats, superhero cape and more
• Cannon skins and backgrounds: Gold, Lava, Shadow, Starry Night, Neon City and more
• Sticker album: collect 16 stickers for beating bosses and hitting milestones
• Daily rewards, a free daily lucky spin and daily missions
• Easy Mode with an aim helper for younger players
• Works offline, with no ads and no sign-up

**App category:** Game > Casual
**Tags:** Casual, Arcade, Action, Offline
**Contact email:** (your support email)
**Privacy policy URL:** (where you host `privacy-policy.html`, see below)

## Graphics (in this folder)

| Play Console field | File |
|---|---|
| App icon (512×512) | `icon_512.png` |
| Feature graphic (1024×500) | `feature_1024x500.png` |
| Phone screenshots (1080×1920, up to 8) | `screenshots/01_crowd.png` … `08_menu.png` |

## App content answers

- **Privacy policy:** host `privacy-policy.html` on your server (or GitHub Pages) and paste the URL.
- **Ads:** No, the app contains no ads.
- **App access:** All functionality is available without special access.
- **Content rating (IARC questionnaire):** Category: Game. No violence beyond cartoon
  (cartoon characters bump into each other and disappear in puffs), no blood, no fear,
  no gambling with real money (the daily spin only gives in-game coins and can't be bought),
  no user-to-user communication, no location sharing, no purchases. Expected: Everyone / PEGI 3.
- **Target audience:** if you include ages under 13 you must follow the Families policy. The game
  already fits it: no ads, no analytics, no data collection, no external links. Choosing
  "ages 5+" is accurate. Choosing only "13+" avoids Families requirements but is less honest
  given the cute art; the choice is yours.
- **Data safety:** "No data collected" and "No data shared". The player name, progress and
  settings are stored only on the device and never leave it.
- **Government apps / financial / health features:** No.

## Release

- Upload `build/android/CrowdCannon.aab` to **Testing > Internal testing** first, install it from
  the Play link on your phone, then promote it to Production.
- **Play App Signing:** accept Google's default (Google holds the app signing key; you keep the
  upload key in `CrowdCannon-release-keys/`, which you must back up).
- **New personal developer accounts:** Google requires a closed test with at least 12 testers for
  14 days before you can publish to Production. Check what Play Console asks for on your account.
