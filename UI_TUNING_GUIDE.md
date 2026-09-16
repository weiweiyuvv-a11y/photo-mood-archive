# UI Tuning Guide

This is the working design direction for the native iOS app. Use it as a Figma checklist while Xcode installs, then mirror the same choices in SwiftUI.

## Product Feel

The app should feel like a private seasonal almanac, not a productivity calendar. The timeline is the archive spine; the doodle mood is the emotional cover for each day.

Good references:
- Instagram Archive for the calendar memory model.
- iOS Photos for trust, local privacy, and calm navigation.
- EMMO for the low-pressure circular mood picker, but not for the overall visual taste.
- A museum field-note book for paper texture, restrained spacing, and private-archive mood.

Avoid:
- Heavy dashboard styling.
- Marketing hero screens.
- Generic purple gradients.
- Complex onboarding before the user sees their archive.
- Overly social/sticker-heavy EMMO styling.

## Core Screens

### 1. Timeline Archive

Purpose: Let the user immediately understand what they photographed each day.

Figma frame:
- iPhone 15 Pro or iPhone 16, portrait.
- Top area: app name, current month, month navigation.
- Horizontal 12-month strip under the header.
- Main area: 7-column calendar grid.
- Each day cell: day number, hand-drawn doodle face, optional tiny photo count and thumbnail strip.

Important UI behavior:
- Empty mood = transparent doodle fill.
- Chosen mood = seasonal color fill.
- Days outside current month are faded.
- Today has a slightly stronger outline, not a loud badge.

### 2. Day Detail

Purpose: Show the day as a tiny memory capsule.

Figma frame:
- Top: large month-specific doodle.
- Beside it: weekday, full date, photo count.
- Mood spectrum card.
- Secret note card.
- Photo grid.
- Soundtrack card for a manually added song/memory note.

Important UI behavior:
- The mood spectrum is left-to-right emotional brightness.
- Voice is the default input affordance, but text remains editable.
- Photos should feel like evidence of the day, not decorative wallpaper.

### 3. Mood Picker

Purpose: Let the user color the day's doodle quickly.

Interaction:
- 9 circular hand-drawn blob faces placed around a center prompt.
- The picker can use soft multicolor EMMO-like mood blobs.
- The saved calendar mark still uses the month hue so the archive remains seasonal and composed.

Mapping:
- Level 0: quiet / transparent-ish / low energy.
- Level 4: ordinary good day.
- Level 8: bright, vivid, high-energy day.

### 4. Voice Note

Purpose: Add an easter egg note without turning the app into a journal chore.

Figma component:
- Card title: Secret note.
- Mic circle button on the right.
- Text editor below.
- Small listening status only while recording.

States:
- Idle: mic.circle.fill in seasonal accent color.
- Recording: stop.circle.fill in soft red.
- Transcript result: text appears in editor and can be changed.

### 5. Trail

Purpose: Offer a secondary map view without stealing the app's main timeline identity.

Behavior:
- Use existing photo GPS metadata from the local photo library.
- Do not request live location permission for the first version.
- Cluster nearby photos into small thumbnail pins with count badges.
- Keep Timeline as the default view; Trail is a quiet alternate lens.

## Seasonal Palette

Use one hue per month. These are already encoded in `ArchiveDesign.months`.

January: icy blue, hue 205.
February: berry pink, hue 342.
March: sprout green, hue 126.
April: rain apricot, hue 32.
May: fresh leaf, hue 96.
June: sun yellow, hue 48.
July: pool cyan, hue 178.
August: peach, hue 24.
September: pencil ochre, hue 58.
October: maple orange, hue 18.
November: dusk violet, hue 274.
December: ribbon teal, hue 158.

Figma formula:
- Background wash: same hue, low saturation, high brightness.
- Mood swatches: saturation 18% to 82%, brightness 96% to 68%.
- Text: warm ink, close to `#2B251E`.
- Secondary text: warm gray, close to `#746B62`.
- Card background: translucent warm white.

## Layout Tokens

Use these in Figma and mirror them in SwiftUI:

- Screen horizontal padding: 18.
- Header vertical gap: 14.
- Month strip item: 52 x 58.
- Calendar grid gap: 8.
- Day tile min height: 104.
- Day tile radius: 16.
- Detail card radius: 18.
- Detail card padding: 16.
- Photo grid gap: 8.
- Thumbnail radius: 8.

## SwiftUI Files To Edit

- `Models.swift`: month names, hues, doodle kind mapping.
- `ContentView.swift`: top header, month strip, app-level background.
- `CalendarMonthView.swift`: calendar grid, day tile sizing, photo count and thumbnails.
- `MoodDoodleView.swift`: hand-drawn doodle shapes.
- `DayDetailView.swift`: mood spectrum, note card, photo grid.
- `VoiceNoteRecorder.swift`: recording state and speech-to-text behavior.

## First Figma Pass

Make four frames:

1. `Month Archive / Empty Permission`
2. `Month Archive / With Photos`
3. `Day Detail / Mood Selected`
4. `Day Detail / Recording Note`

Then test these questions:

- Can I understand this is a photo archive within 3 seconds?
- Does the doodle feel like a daily cover, not a reaction sticker pasted on top?
- Does the month color feel seasonal without making the whole app one-color?
- Is the voice note clearly available without making text editing feel secondary?
- Can this fit on a small iPhone without the calendar becoming cramped?
