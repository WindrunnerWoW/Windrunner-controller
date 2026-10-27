# Appearance

Open `/controller` and choose **Appearance**. Changes update the existing UI immediately
and are stored with the character's current profile.

The Controller Setup window uses textured slate panels, warm metal trim and
illustrated category icons. Serif headings use the client's
bundled display font; Latin body text uses its bundled sans font. Localized fonts
are preserved. Settings values sit in recessed fields, action rows have an arrow,
and the quick menu uses an engraved dial. Modern action-button rims follow the
profile's accent while preserving range and resource indicators.

Settings have larger category buttons and a persistent controller hint. The centered window
fits the screen with a 16-unit margin. Checkbox focus includes its label.
Every preference occupies one row. Up/down chooses a row and left/right changes
its value; mouse left/right clicks increase/decrease the new appearance choices.

Choose **Ember**, **Frost**, or **Grove** for a warm bronze, blue, or green palette.
An accent can follow that theme, use one of five color choices, use the character's
class color, or use the color picker. Cancelling the picker restores the previous
choice. Very dark accents are lifted for readable text and focus outlines while
decorative accents retain the selected color. Theme changes apply to addon-owned settings, the virtual keyboard,
controller focus outlines, action placement, action-page prompts and the radial
quick menu. Blizzard and other addons' frames retain their own styles.

| Control | Range | Effect |
| --- | --- | --- |
| Panel opacity | 72–100% | Backdrops retain readable text and icons. |
| Settings scale | 65–125% | Settings window; automatically capped to fit the screen. |
| Quick-menu scale | 65–130% | Radial menu; automatically capped to fit the screen. |
| Text size | 90–120% | Addon settings and keyboard labels. |
| Focus outline | 1–4 | Thickness of the controller selection outline. |
| Show navigation pointer | On/off | Optional arrow beside the focus outline; disabled by default. |
| Hint duration | 1–6 seconds | Duration of controller mode and status notifications. |
| Reduce animation | On/off | Opens the quick menu instantly and disables hint fading. |

**Compact**, **Balanced**, and **Large** adjust main action-button size and the
spacing within and between the two controller clusters. **Classic** and **Modern**
select the existing action-button styles. Position, scale, actions and bindings
remain as configured; further adjustments are available in **Bars**.

**Controller labels** controls the small input symbols on the action buttons.
New and existing profiles start with **Reference symbols**: bare controller
glyphs above the action icons. **Round badges** restores the previous large
labels with circular backgrounds. Applying either preset resets label settings.

Show or hide the labels independently, toggle their badge backgrounds, choose
a size from 8–48, and anchor them at the top, bottom, left, right, or center of
each action button. Horizontal and vertical offsets range from −80 to 80.
These changes apply to all controller labels, follow the action-bar scale, and
leave the action buttons' size, position, artwork, and bindings as configured.
Labels update immediately and save with the profile, including profile exports.
The clusters' screen fitting includes visible labels at their customized positions.

**Reset appearance** restores the theme, accent, menu sizes and readability
options. It preserves action bars, bindings and profiles. Loading another profile
repaints and resizes already-open UI without requiring a reload.

Lua 5.0 regression checks cover live controls, mouse handlers, profile refresh,
color-picker cancellation, settings isolation, font scaling and small-screen
fitting. Layout previews use the actual Lua-created frame geometry with
the bundled artwork and approximated fonts. Native template widgets and game
icons are only partly represented. They are not screenshots from the game. Follow the visual
checks in [Controller acceptance](ControllerAcceptance.md) before judging final
in-game rendering or controller feel.

The tintable UI textures are built reproducibly with
`python scripts/generate-ui-textures.py` (Pillow required). The addon loads the
generated `.tga` files directly; users do not need Python.
