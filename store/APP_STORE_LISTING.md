# App Store listing: Crowd Cannon

What to enter in App Store Connect for the iPhone and iPad release. Publishing needs a paid
Apple Developer Program membership; the free Apple ID route in the README only installs the game
on your own phone.

## Build and upload

1. Join the Apple Developer Program and add the account in Xcode → Settings → Accounts.
2. Put your 10-character Team ID in `export_presets.cfg` → `application/app_store_team_id`
   (it replaces the `SETINXCODE` placeholder, so every export keeps your signing team).
3. Export the Xcode project with the **release** template (the debug one is only for testing):
   `godot --headless --path . --export-release "iOS" build/ios/CrowdCannon.ipa`
4. In App Store Connect → Apps → **+ New App**: platform iOS, bundle ID
   `com.tejastelkar.crowdcannon`, SKU `crowdcannon-ios`, primary language English.
5. Open `build/ios/CrowdCannon.xcodeproj`, pick **Any iOS Device (arm64)**, then
   Product → Archive → Distribute App → App Store Connect → Upload.
6. Bump `application/short_version` and `application/version` in `export_presets.cfg` for every
   new upload (the build number must always go up).

## App information

| Field | Value |
|---|---|
| Name (30 max) | Crowd Cannon: Bloop's Battle |
| Subtitle (30 max) | Shoot, multiply, smash castles |
| Primary category | Games, subcategories Casual and Action |
| Content rights | Contains third-party content: yes, and you have the rights (CC0 models and sounds from Kenney and Quaternius, Lilita One font under the SIL OFL; licences in `assets/licenses`) |
| Privacy policy URL | Required. Host `store/privacy-policy.html` after filling in the contact email |
| Support URL | Required. Any page with a way to contact you (it can live next to the privacy policy) |
| Copyright | 2026 Tejas Telkar |
| Price | Free, all countries |

**Age rating questionnaire.** Answer *Cartoon or Fantasy Violence: Infrequent/Mild*: red and
blue crowds bump into each other and vanish in puffs, and castles crumble. Everything else is
*None* or *No*:

- no realistic violence, horror, profanity or mature themes
- no gambling or contests: the daily lucky spin is free and only pays coins, which can't be bought
- no user-generated content, chat or web browsing
- no ads, no in-app purchases

Apple works out the rating from these answers.

**App Privacy.** Choose *Data Not Collected*. The game has no accounts, ads, analytics or network
access, and the save (progress, settings, the player's name) stays on the device.

**Export compliance.** Nothing to answer: the build already declares
`ITSAppUsesNonExemptEncryption = NO`, because the game uses no encryption.

## Version 1.0.0

**Promotional text** (170 max)

Hold to fire, drag to aim! Grow a giant army, break barrels for bigger cannons and smash the
red castle with Bloop. Free daily spin and missions!

**Keywords** (100 max, comma-separated, no spaces)

crowd,cannon,shooter,army,gates,castle,multiply,runner,mob,casual,offline,boss,bloop,arcade,barrel

**Description**

Fire your cannon, multiply your army and overrun the enemy castle!

Hold to shoot and drag to aim. Send your crowd through + gates and the rare x2 and x3 gates to grow a huge army,
dodge the sneaky ÷ traps, and crash into the red castle before their army gets through. Charge up
your Champion to smash everything in its path, and face giant slimes, skeleton mini-bosses and dragon bosses.

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

## Screenshots

The Google Play screenshots (1080 × 1920) are the wrong shape for the App Store. Apple needs:

| Display | Size (portrait, pixels) | Required? |
|---|---|---|
| iPhone 6.9" | 1320 × 2868 or 1290 × 2796 | Yes, 1 to 10 images (smaller iPhones reuse them) |
| iPad 13" | 2064 × 2752 or 2048 × 2732 | Yes, because the build supports iPad |

The export targets iPhone **and** iPad (`application/targeted_device_family = 2`), so Apple also
reviews the game on an iPad. It's built for that: wider screens keep the whole lane in view.
If you'd rather ship iPhone-only, set it to `0`. iPads then run the iPhone version in a window,
and no iPad screenshots are needed.

## Already checked in the build

- Installs on iPhone XS / XR and newer, iOS 15 or later. The A12 chip requirement is added by
  Godot's Metal renderer.
- Portrait only, full screen, status bar hidden.
- App icon 1024 × 1024 without transparency.
- Privacy manifest (`PrivacyInfo.xcprivacy`) included.
- The Release configuration compiles for devices with Xcode 27.
