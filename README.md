# ayijeUIQOL

A quality-of-life addon for World of Warcraft Retail.

## Installation

Install `AyijeUI`, `AyijeUI_Options`, and `ayijeUIQOL` in
`World of Warcraft/_retail_/Interface/AddOns/` and enable them in the addon list.

## Configuration

Open `/aui` and select **Extras > Quality of Life**. The **Enable** switch controls
the QoL module without reloading the UI.

All QoL features are enabled by default. Existing saved settings, including
explicitly disabled features, are preserved. New features must follow this rule;
see `AGENTS.md`. Settings sections remain collapsed by default.

### Progress bars

**Progress Bars** in **Extras > Quality of Life** adds XP-style settings for
reputation/renown, honor, artifact, Azerite, housing, and scenario/encounter
progression. Each bar has width, height, font size, text visibility (always,
mouseover, hidden), fill color, background opacity/color, position and a preview.
The settings sections are collapsible and initially closed. All new bar types
are enabled by default but show only when their native progression is applicable.
Position them with their settings or the corresponding `/amover` handles.
**Show Name** includes the tracked faction or scenario objective alongside the
values and percentage, and is enabled by default. **Match XP Appearance** copies
the current XP dimensions, font size, text visibility, fill color and background
to that bar. It preserves its enabled state, identifying name and position.
**Match XP Position** separately copies the XP anchor and offsets when you want
both bars at the same location. These buttons copy once; later changes remain
independent, including their color tables.

The existing AyijeUI XP bar stays under **Action Bars > Experience Bar** with its
current settings. The new bars remain visible even when that XP replacement hides
Blizzard's tracking manager. Each type owns a separate position; defaults leave
space above the XP bar. Disabling a type or this QoL restores its original native
appearance and input handling, without changing XP settings or manager visibility.

Blizzard's native tracking bars supply the progress values, including friendship,
renown and paragon normalization. Scenario/encounter bars mirror native single,
double and unit-power widgets from the power-bar, top-center and below-minimap
containers. Multiple active bars stack under the scenario position. They disappear
when Blizzard hides or recycles their widgets. Boss-ability timelines are separate.
Native value updates drive the bars without a polling loop; restricted values
are forwarded to bar setters without arithmetic. Protected native input changes
are deferred until combat ends. Native update methods and event registrations
are preserved. These interfaces follow Blizzard's
[tracking manager](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ActionBar/Shared/StatusTrackingManager.lua)
and [widget implementations](https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns/Blizzard_UIWidgets).

### Merchant catalog cost

**Merchant Catalog Cost** in **Extras > Quality of Life** is enabled by default.
A coin button beside the merchant opens or collapses an AyijeUI-styled cost panel.
The expanded state is saved in the current AyijeUI profile and can also be changed
in the collapsed QoL settings section. The panel hides on the buyback tab and
closes with the merchant. Long resource lists scroll with the mouse wheel.
Resources use compact merchant-style blocks: a 32px icon with AyijeUI's native
inset and global border, a subtle background, then name above owned / required.
A signed balance aligns at the right (`-` missing, `+` remaining). Full cost,
owned-stock and balance labels are available on hover.

Totals cover **one purchase lot of each in-stock offer**, across every page of
the native class/specialization-filtered catalog. A stack sold as one lot uses
the lot price once; stock quantity does not multiply its price. Sold-out offers
are excluded, and free offers add no cost. This does not attempt to buy every
copy in stock, skip collected appearances, or spend anything automatically.

Gold, each currency ID and each payment-item ID have separate totals, even when
they share the same icon. Each resource shows required and owned amounts, then
a green remaining balance or red deficit after purchasing the complete catalog.
Owned item counts match Blizzard's merchant stock query: bags and reagent-bank
stock, excluding personal and Warband banks. Native API arguments are documented
in Blizzard's [generated Item API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua).

Missing catalog/cost data is explicitly marked as a partial total with `+` and
neutral colors; no final balance is claimed until the costs are complete.
Unknown resource balances display `?`. Purchases, stock/filter changes, money,
currency and bag updates refresh the panel. No FunelQOL installation is needed.

### Character sheet

The collapsed **Character Sheet** section in **Extras > Quality of Life** enables
upgrade-track colors on AyijeUI's existing character and inspect item-level text.
It respects **Gear Info** visibility and font settings, enchant labels and sockets.
Untracked items keep AyijeUI's quality color. Disabling track colors restores it.

**Crest Budget** adds an AyijeUI panel beside the equipment sheet, showing owned
crests / estimated requirements for finishing the current tracks of equipped
items. Green means sufficient stock, red means a deficit. The tooltip explains
the estimate and shows the deficit numerically. Colors can be disabled separately.
The panel follows the equipment tab and closes with it.

Midnight seasons 1 and 2 are supported. The estimate is 20 crests per remaining
rank before discounts; it excludes other currencies, un-equipped items and
changes to a different track. Known old-season gear is excluded. Season bonus
IDs or a positive native current-item result identify current equipment. Items
with the same native upgrade track, rank count and maximum item level share
proven seasonal provenance from other equipped gear, including fully upgraded
items. When Blizzard returns a zero maximum (observed on a Hero necklace), an
exact match of track, rank count, current rank and current item level provides
the same evidence. Conflicting or unmatched ladders remain unresolved; current
item level alone is never used to guess a season. Missing item data and unidentified seasons
produce a partial lower-bound estimate marked `+`, with neutral sufficient-stock
colors. Each crest tooltip lists included items, ranks and individual costs, plus
unresolved items excluded from that crest's total. Hold Shift while hovering to
see native track/rank/level diagnostics for exclusions. Unsupported seasons are
explicitly unavailable.
No upgrade NPC interaction or other addon is required. Native item and upgrade
fields follow Blizzard's [generated Item API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua).

**Reputation Tab Skin** uses AyijeUI fonts, flat surfaces, borders and status-bar
texture while retaining native standing colors, values and collapse controls.
Pooled rows are restyled as the list updates. **Currencies Tab Skin** styles list
surfaces, filters and the options popup, preserving native currency rows and
Warband transfer controls. Both skins restore their prior appearance on disable.

The character and inspect windows reuse AyijeUI's existing skins. Their shared
toggles are also exposed in this QoL section and require a reload, as in AyijeUI's
Skins page. They remain normal AyijeUI settings, independent of the QoL master.
The new track, budget and tab features are all enabled by default and toggle live.

### Loot window

**Loot Window** in `/aui` > **Extras > Quality of Life** adds these default-on
options to AyijeUI's styled loot window:

- **Take All Button**: an arrow/tray glyph beside the close button calls native
  `LootSlot` for all loot slots, retaining Blizzard's confirmation/error behavior.
- **Take All Keybind**: default `E`. Enter a key such as `E`, `SHIFT-E`, or
  `CTRL-SPACE`; an empty field disables the shortcut. Only the matching key is
  intercepted, while the loot window is visible, and never while typing in a box.
  Ordinary keys/combos work outside combat; standalone `SHIFT`, `CTRL`, or `ALT`
  also work in combat. The button itself remains clickable.
- **Open at Cursor**: opens at the cursor position captured when shown, with the
  window's effective scale respected. Disabling restores its saved anchor;
  disabling the feature restores the previous `lootUnderMouse` CVar.
- **Show Item Level** and **Item Level Font Size**: display equipment level on
  loot icons, using Ayije's global font. Money/currency/non-equipment rows remain
  unchanged; uncached item data updates on load.

The section is collapsed by default and requires AyijeUI's Loot module and
**Restyle Loot Window**. The controls do not replace the native loot rows or
Ayije's faster auto-loot behavior. Edit Mode previews do not take loot or use the
cursor anchor. All settings are part of AyijeUI profiles.

### Clickable buff reminders

Enable **Clickable Buff Reminders** to left-click existing AyijeUI Cooldown Manager
raid-buff icons outside combat. This casts your known class buff on yourself;
group-wide buffs also affect nearby allies. Supports Mark of the Wild, Arcane
Intellect, Battle Shout, Power Word: Fortitude, Skyfury, and Blessing of the Bronze.
This option is on by default and requires `AyijeUI_CooldownManager`.

The existing display, positioning, and missing-buff detection stay in Cooldown
Manager. Clicks are disabled during combat and in the CDM editor/previews.
External buffs such as Source of Magic and Symbiotic Relationship are excluded
because they require selecting another recipient. No RefineUI or FunelQOL
installation is required.

### Bag appearance markers

Enable **Bag Appearance Markers** in `/aui` > **Extras > Quality of Life**.
This collapsed section controls AyijeUI's bags, personal bank, and Warband bank
only. Blizzard and other addons' item buttons are not modified.

By default, only missing appearances are marked: a transmog icon for your character
and a gray cross for other classes. **Show Collected Appearances** adds checks;
**Show Other Classes** and **Raid Tokens** independently control those categories.
Choose marker size, anchor point, and X/Y offsets. Collection ownership includes
the same visual learned from another item, rather than requiring this exact source.
Raid-token mappings are bundled from RefineUI and preserve difficulty and faction;
eligible tokens show your class's status, otherwise the other classes' combined
status. Unknown item/collection data is left unmarked and retried on data events.

**Token Collection by Class** (on by default) adds each eligible class and its
collected/uncollected status to token tooltips in Ayije bags and both banks.
Multi-appearance tokens include a collected/total counter; unresolved collection
data displays a loading status. The block uses the token's exact difficulty and
faction and refreshes with native tooltip rebuilds and collection updates. This
tooltip detail remains available even when collected markers or other-class
markers are hidden. Disabling **Raid Tokens** also disables the tooltip block.

**Upgrade and Catalyst Hints** adds separate native icons for missing appearances
reachable by an upgrade, catalyst conversion, or both. The implementation uses
Blizzard's eligibility APIs and explicit Midnight season 1/2 tier-set mappings.
It checks exact item provenance for a plain upgrade; an arbitrary same-slot item
is not assumed to grant a tier appearance. Exact bundled client source IDs fill
gaps in Blizzard's set-slot lists. Warbound-until-equipped seasonal armor can show
a catalyst preview for the correct armor class even before native conversion is
available; its tooltip says to equip or bind it first. Bound items rejected by the
native conversion API do not use this preview. Unsupported seasons, tracks, missing
data and PvP routes are left unmarked. Eligibility checks resume after combat.
These hints do not promise that you currently have the currencies/charges needed.
No NPC interaction, purchases, conversion, or wardrobe-filter changes occur.

No RefineUI, FunelQOL, or TransmogUpgradeMaster installation is required. The master
toggle is on by default, settings use AyijeUI profiles, and disabling it removes
all owned markers immediately. See `THIRD_PARTY.md` for the token data attribution.

### Bag item level upgrades

**Bag Item Level Upgrades** (on by default, collapsed section in `/aui` >
**Extras > Quality of Life**) adds a green arrow beside AyijeUI's item level on
equipment (with a dark outline for contrast) in the bags, personal bank, and Warband bank when its current item level
is higher than what you wear in that slot. Rings, trinkets and dual-wielded
one-handers compare against the lower of the two equipped items; an empty slot
always counts as an upgrade. An off-hand compares against an equipped two-hander.
The tooltip shows the gain and the equipped item level. Choose the arrow size.

Only items your character can use are marked: wrong armor type (except cloaks),
cosmetic armor, items above your level and those Blizzard reports as unusable are
skipped. The comparison is item level only; it does not consider specialization,
main stat, secondary stats or set bonuses. Refreshes on equipment and level changes.

### Set collection board

**Set Collection Board** (on by default, collapsed section in `/aui` >
**Extras > Quality of Life**) docks an AyijeUI-styled panel to the right of the
Collections journal whenever the **Sets** tab of Appearances is visible (Blizzard
or BetterWardrobe). Each row is a set label, each column a class; sets are
grouped by expansion (click a header to collapse it) and split into **Raids**,
**PvP** and **Other** tabs. It is a standalone rewrite of the MogBoard idea with
no library or addon dependency; disable MogBoard to avoid two panels.

- A check tinted LFR / Normal / Heroic / Mythic marks the highest difficulty you
  completed; a gold bar shows progress on started sets. The tooltip lists every
  variant with its collected count.
- Left-click shows the set in the Sets collection (switching the class filter);
  clicking again cycles through difficulties. Right-click toggles the wishlist;
  the **Wishlist** button filters the tab to wished sets.
- Shift+right-click a class icon to hide its column; **Hidden (n)** restores it.
  Wishlisted classes cannot be hidden.
- **Raid Lockouts** marks raids this character is saved to (orange: partial,
  red: cleared) with remaining bosses. **Warband Lockouts** remembers lockouts of
  your other characters until reset (stored beside the profiles, not exported)
  and lists them on the raid name. Lockouts match by instance map ID, then name.
- **Raid Collection Report** prints the set appearances you gained in a raid
  when you leave it, wishlisted sets first and starred, with a note when a set
  is completed.
- **Open on Sets Tab** switches Appearances to Sets while the board is shown.
  The arrow at the journal's bottom right shows or hides the board; `/setboard`
  opens it directly.

### CDM keybinds

Enable **CDM Keybinds** in the QoL page to show action-bar shortcuts on AyijeUI
Cooldown Manager viewer icons and custom spell icons. The section is collapsed
by default. Set text size, color/opacity, anchor point, and X/Y offsets there.
It uses AyijeUI's global font and keybind abbreviations, including identifiable
macro spells and base/override spell variants. Unbound spells show no label.

Binding, action-bar, macro and specialization changes refresh the text without
polling. Viewer spell IDs come from configured metadata, not active aura data.
The feature is on by default, requires `AyijeUI_CooldownManager`, and saves its
settings in AyijeUI profiles.

### Rotation recommendation and cooldown cast alert

Both displays have separate, default-on toggles in **Extras > Quality of Life**.
**Rotation Recommendation** shows Blizzard's next recommended spell, its current
action-bar keybind, and the global cooldown. It is a visual guide: use your normal
action-bar keybind to cast. It hides when Blizzard has no recommendation or the
assisted-combat API is unavailable.

**Cooldown Cast Alert** shows the last spell you attempted while it was on a real
cooldown (excluding the global cooldown alone), displays the native cooldown swipe
and countdown, then shows **Ready** for a configurable duration. Failed spellcasts
and recent action/macro attempts followed by a cooldown error supply the spell.
Restricted spell IDs or cooldown flags are skipped rather than inspected.

Both icons share the rotation icon's width, height, keybind and spell-name text,
hover color, and slot background, using AyijeUI borders and global fonts. Visibility
and cooldown swipe/text remain configurable per display.

The cooldown icon is anchored to the rotation icon by default. Choose **Anchor
Side** (right, left, top, bottom) and **Spacing** in its QoL options. Move the pair
using the rotation position or its `/amover` handle. The alert remains visible when
the recommendation disappears. **Preview** shows both enabled icons together.
Turn off **Anchor to Rotation Icon** to position the alert independently.
Settings are included in AyijeUI profiles. Neither feature depends on FunelQOL or
RefineUI.

Settings are stored in `AyijeUIDB.qol` and included in AyijeUI profile saves,
loads, imports, and exports (under **Extras**). Existing `ayijeUIQOLDB` settings
are migrated on first load when no AyijeUI QoL settings exist.

The options page is hidden when `ayijeUIQOL` is not loaded. AyijeUI remains usable
without the QoL addon.

### Plumber difficulty selector skin

Plumber's entrance difficulty selector uses AyijeUI's flat dark panel, global
font, registered borders, gold selection outline, and subtle hover fill. Native
difficulty changes, lockout counts, warnings, tooltips, fades, and positioning
remain controlled by Plumber. The skin is on by default and can be switched off
live in `/aui` > Extras > Quality of Life > Plumber Difficulty Selector, restoring
Plumber's artwork and fonts. Requires Plumber's Instance Difficulty module to be
enabled. Plumber itself is optional.

### TeleportMenu skin

TeleportMenu buttons, flyouts, and housing teleports use AyijeUI's registered
borders, icon crop, subtle hover fill, and global font. Equipped items retain a
green border matching AyijeUI action buttons. Native clicks, tooltips, cooldowns,
button size, and menu layout stay managed by TeleportMenu. Enabled by default;
toggle it in `/aui` > Extras > Quality of Life > TeleportMenu Skin. **Icon Spacing**
sets a visual gap from 0 to 12 pixels (4 by default), including flyouts. Icons,
borders, hover fills, and cooldowns are inset within the native button slots.
Disabling
restores the original artwork and fonts. Changes during combat apply after
combat ends. TeleportMenu is optional.

### RetroRuns skin

RetroRuns windows (main panel, minimized route bar, transmog browser, skips,
skip details, achievements, load dialog, copy window, and their search popups)
replace the ornate backdrop with AyijeUI's flat panel fill and registered border.
RetroRuns' own panel opacity setting still scales the fill. Layout, fonts,
buttons, and behavior stay managed by RetroRuns, and none of its files are
modified. Enabled by default; toggle it in `/aui` > Extras > Quality of Life >
RetroRuns Skin. Disabling restores the original artwork. RetroRuns is optional.

### World map labels and delve grades

**World Map Labels** in `/aui` > Extras > Quality of Life adds names above native
raid, dungeon, and delve entrance markers. Each category and the font size can
be configured separately. All categories and delve grades are enabled by default.
The labels use AyijeUI's global font and do not change native markers or clicks.

Recognized Midnight delve stories append a colored reference grade, for example
`Catastrophe collégiale - S`. The twelve-delve catalogue is copied from your
FunelQOL reference list: grades belong to individual story variants, not raids or
the delve as a whole. Localized achievement criteria and known aliases identify
the active story through Blizzard's widgets. Missing, unrecognized, conflicting,
or restricted story data leaves the name without a grade. These are your supplied
reference ratings, not a live community ranking. Neither FunelQOL nor RefineUI is
required. Labels are hidden in combat and restored afterwards; the module never
opens the map or refreshes its native data providers.

### Rare map pins and exploration mode

**Rare Map Pins** places the known rares of the rare tracker catalogue on the
world map. Defeated rares are greyed out. Pins show a tooltip with the
coordinates and kill status; clicking one sets a waypoint. Names can be hidden,
shown on hover (default), or always shown, and icon and name sizes are
adjustable. Pins are hidden inside delves. Locations are known spawn points and
do not confirm that the rare is currently up.

The world map settings menu (the filter button) gets two AyijeUI submenus:
**Rares** with the same options plus **Declutter**, and **Readability** with an
**Exploration mode** that hides world quest and available side quest markers.
These use Blizzard's own map filters; your previous choices are saved and
restored when exploration mode is turned off or the feature is disabled.
Configure it in `/aui` > Extras > Quality of Life > Rare Map Pins.

### Edit mode settings shortcut

Right-click an AyijeUI mover in `/amover` to leave edit mode and open the
corresponding settings page. Unit frames and action bars select their matching
section; QoL displays expand their settings group. Works on both unselected and
selected movers, outside combat. Left-click selection and dragging remain native.
Enabled by default; disable **Right-click to Open Settings** in `/aui` > Extras >
Quality of Life > Edit Mode Shortcuts to restore native right-click selection.
Unrecognized movers retain their native behavior.

### Progress notifications

**Progress Notifications** in `/aui` > Extras > Quality of Life adds three
default-on categories to AyijeUI's existing loot feed: achievements, character
level-ups, and reputation ranks / renown levels. Each category has its own toggle
and **Test** button (the reputation test displays both a standing and a renown
example). Requires AyijeUI Loot and its Feed to be enabled. Rows inherit the
native feed's position, font, colors, animation, and notable lifetime.

Only actual events produce notifications: no replay on login, ordinary reputation
gains do not trigger rank notifications, and unrecognized/restricted data is
skipped. Traditional ranks use Blizzard's localized standing-change system
message, including factions in collapsed headers; renown uses the explicit old
and new levels from the native event. Existing Blizzard banners remain unchanged.

### Global interface styles

`/aui` > Extras > Quality of Life > **Interface Styles** offers **Blizzard,
Ayije, Pixels, RefineUI, and Cooldown** for the shared AyijeUI skin system.
Ayije is the default and preserves its existing appearance. Each style keeps
separate choices for border artwork, border size, bar texture, and panel texture.
The border can use AyijeUI's global color or a separate color saved per style.
Use **Style Default** for the preset or choose individual textures. **Keep AyijeUI
Settings** preserves existing bar selections or flat panels. Fonts stay controlled
by AyijeUI's Global settings. These choices are saved in AyijeUI profiles.

All style changes require `/reload` so existing, pooled, and protected elements
use the same settings. Blizzard selects Blizzard border artwork; it does not
restore the entire native Blizzard UI or disable AyijeUI modules. Shared borders,
flat panels, and resolved statusbar textures follow the theme across AyijeUI and
QoL. Purpose-built art such as cast/channel atlases, circular aura rings, portraits,
and separators retain their specialized rendering. Other addons are not reskinned.

AyijeUI_CooldownManager also follows the selected border, base border color, and
resolved bar texture, including icons and resource bars. Its conditional, press,
and pandemic colors retain priority. Existing CDM display settings are not
rewritten; disabling the style system restores their normal use after reload.

Borders use AyijeUI's eight-piece renderer and pixel helpers: corner sizes, edge
thickness, and offsets are rounded at the region's effective scale. UI scale and
display changes recalculate the border geometry; protected frames wait until
combat ends. Semantic hover, item-quality, equipped, and dispel colors remain.

Pixels and RefineUI media and D1 are imported locally into `Media/Local`, with a
SHA256 manifest. They do not require FunelQOL, RefineUI or EllesmereUI to be enabled.
Those local assets are excluded from Git; see `THIRD_PARTY.md`. Missing local
artwork falls back to AyijeUI's border/bar or a solid panel.

## Dynamic anchors between AyijeUI elements

`/aui` > Extras > Quality of Life > Dynamic Element Anchors is enabled by default.
Unlock AyijeUI's movers (or use **Move Elements**), then drag a handle near another
element. A green preview shows the persistent link that will be saved on release.
The registry covers elements exposed through AyijeUI movers, including action
bars, unit frames, the minimap, progress bars and QoL trackers. Targets and sources
use stable frame/configuration IDs; settings are saved per AyijeUI profile.

The same section allows an explicit source, target, side, alignment, spacing and
edge offset, or detachment. A position edit, Reset or a new drag releases the old
link. Trackers retain their header shortcuts and automatic shared-width rows.
Cycles are rejected across native elements and trackers together. Old drag
callbacks cannot write into a newly selected profile.

Protected elements such as action bars are represented to trackers by independent
unprotected proxy rectangles. The anchor engine only reads/writes their geometry
outside combat; combat changes resume when combat ends. No tracker is directly
anchored to a protected bar. Turning the QoL off restores the native mover positions
and clamping. Late-created elements resolve when their movers become available.

## Custom panels and trackers

`/aui` > Extras > Quality of Life > Custom Panels and Trackers manages independent
panels. The feature is enabled by default and initially creates one currency panel.
Create, duplicate, rename, hide or delete panels; choose their content, position,
width, maximum scrollable height, scale, font size, row height, background and
progress bars. Settings follow the active AyijeUI profile. Sections start collapsed.
Left-click a panel header to fold/unfold it. Right-click opens a context menu for
content, tracked rows, anchoring, duplication and full settings. Ctrl-left-click
creates a new tracker attached to that panel's right edge; Ctrl-right-click deletes
it (the shortcut preserves the final panel). Shift-drag the header to move freely:
a green preview shows a nearby snap target, and releasing attaches the tracker.
Dropping away from another panel leaves it free. These edit gestures are disabled
in combat. Header tooltips list the shortcuts.

Dynamic Anchoring also exposes the target, side, alignment, spacing and offset in
the QoL options. Linked panels follow movement, resizing and folding automatically,
with a stable gap across different scales. Targets include the QoL reputation,
honor, artifact, Azerite, housing and scenario bars, AyijeUI's XP bar, and compatible
elements registered with AyijeUI's movers, using independent proxies for protected
frames such as action bars. Shift-drag near a visible
target to preview/drop the link, or choose it from the context menu/options.
Hidden targets are not snap candidates; existing links remain saved. Late-created
targets are resolved lazily, including after a reload. Cycles are rejected. Deleting a parent
releases its followers at their current screen positions. AyijeUI movers remain
supported; moving a linked tracker releases its previous link and may snap to a
new nearby tracker. A profile change cancels an active shortcut drag; old menus
cannot modify a different profile or a deleted/reused panel.

**Share Target Width** is enabled by default in Dynamic Anchoring and the header's
Anchor menu. Trackers above or below the same external target share its full
rendered width, with spacing subtracted before dividing into equal slots. This
also includes trackers linked horizontally to those panels. For a 560-wide bar
and an 8-wide gap, two panels are 276 wide each; three are about 181.3 wide each.
Each side of the bar forms a separate row. Scales are accounted for, hidden panels
stop consuming a slot, and folded headers keep theirs. Target size changes refresh
the layout automatically. The stored manual width is preserved and restored when
sharing is disabled or the panel is detached; the manual width slider is disabled
while automatic sizing is active.


The fourteen content types are currencies/gold, professions, tracked quests,
delves, delve quests and leveling activities, Great Vault, renown, weekly goals,
rares, teleports, raid sets, raid collection, custom text and preview. Catalog-based
panels allow up to eight selected entries, in order. Currency IDs can be entered
directly (`-1` gold, `-2` current-season crests). Custom text provides eight
label/value pairs. Quest panels support automatic/manual selection, objectives,
details and foldable sections; delves provide filtering/sorting. Raid collections
follow the last visited raid and its difficulty, with category and ownership
filters and foldable bosses. Renown selections persist separately per expansion.

Rows retain native quest, waypoint, profession, renown, vault and collection
interactions. Teleport icons use hardware clicks outside combat; combat prevents
casts. Providers are isolated in `TrackerContent`; AyijeUI supplies the rendering,
fonts, borders, movers and settings. FunelQOL, RareScanner, TeleportMenu and
TransmogUpgradeMaster are not required for these trackers.

The local recovery snapshot contains 11 saved FunelQOL layouts and weekly memories
for six characters. **Recover FunelQOL Panels** imports a chosen layout as additional
panels. It does not replace existing panels or modify original saved variables.
Positions, links between panels and supported content selections are converted; all imported panels use
AyijeUI's appearance. Weekly memory lives in `ayijeUIQOLCharacterDB`, separately
from profile settings, and expires at the weekly reset. To regenerate the local
snapshot, exit WoW and run `python tools/Import-FunelTrackers.py` (requires lupa).
New snapshots are captured when initializing a new profile; existing profiles
retain their original recovery snapshot.

Rare/teleport catalogues and the recovery snapshot are local copies excluded from
Git; preserve them when moving this installation. See `THIRD_PARTY.md` for origins
and redistribution restrictions. Native APIs provide live progress and ownership;
missing data remains pending rather than being counted as uncollected. Automated
Lua fixtures cover providers, imports, lifecycle, interactions and native option
bindings; final layout and hardware casting still need validation in the client.

### Adaptive minimap button bar

**Minimap Button Bar** in `/aui` > Extras > Quality of Life docks AyijeUI's addon
button bar to the top, bottom, left, or right of the visible minimap. Its width
matches the minimap's screen width, including the minimap's own scale. Buttons
resize between configurable minimum/maximum sizes and wrap into balanced rows;
partial rows are centered. Spacing and distance from the minimap are configurable.
The default is below the minimap, 6 units away, with 4-unit spacing and 20–32-unit
icons. Layout is computed in physical pixels and follows live minimap resizing,
scale changes, button additions and visibility changes.

Enable AyijeUI's addon-button bar first. An explicit **No Anchor Bar** setting is
respected. While docked, move the minimap in edit mode to move both together.
Independent bar placement, dimensions, and buttons-per-row settings resume when
the QoL feature is disabled. Mouseover and pet-battle visibility remain native.
Changes during combat apply after combat ends. This feature is on by default.

### Standalone clock

**Standalone Clock** in `/aui` > Extras > Quality of Life detaches the AyijeUI
clock from the minimap. It is enabled by default, starts near the bottom center,
and has its own **QoL Clock** mover in `/amover`, plus screen anchor and X/Y
offset settings. Right-click its mover to open its QoL settings. It remains
functional even when the AyijeUI Minimap module is disabled.

The first activation copies existing native clock preferences for local/server
time, 12/24-hour format, font size and color. Subsequent changes are independent
and saved in AyijeUI profiles. It uses AyijeUI's global font and pixel helpers.
Only one clock is displayed: the native minimap clock and its timer subscription
are suspended while this standalone clock is enabled. Disabling it cancels its
timer and restores the native minimap clock according to its original settings.

### Legacy Completionist tracker

**Legacy Completionist** in `/aui` > Extras > Quality of Life adds a
**Collection** section under the objective tracker while you are inside a dungeon
or raid. It lists, per boss, the appearances (other classes included), mounts,
pets, toys and related achievements you are still missing, with a collected/total
counter in its header. It is enabled by default and works without RefineUI or any
other addon.

By default it only appears in legacy instances (legacy loot mode); disable
**Legacy Instances Only** to track every dungeon and raid. **Hide Collected**,
**Auto Collapse** (only the next boss with missing entries stays open) and one
toggle per category are available. Click a boss to expand it, right-click the
header to jump to a boss or refresh, hover a line for the item or achievement
tooltip, click an achievement to open it, and use Ctrl/Shift-click to link or
preview an item.

The panel reads the Adventure Guide loot tables (selection and filters are saved
and restored, and nothing is scanned while the guide is open or in combat), the
shared appearance collection service, the mount/pet/toy collections and the raid
achievement snapshot. Nothing is saved: data is rebuilt on each instance entry.
Boss progress comes from encounter events and saved lockouts.

### Tracker skin

**Tracker Skin** in `/aui` > Extras > Quality of Life skins the objective tracker
like RefineUI does, without requiring it. It is enabled by default and each part
has its own toggle:

- **Header Bars**: a class-colored bar under every tracker category
  header (quests, campaign, world quests, achievements, scenario, ...), including
  modules that Blizzard adds later.
- **Instance Art**: inside dungeons and raids, the Adventure Guide artwork of the
  instance is drawn behind the scenario block; inside delves, the delve entrance
  scene is used. Blizzard's own banner fades out while the art is shown and comes
  back when you leave, when you disable the option, or in Mythic+ (which keeps its
  challenge block).

The skin is visual only: it never changes tracker layout or collapse state, skips
combat and secret-value states, and restores everything when disabled.

## Adding features

The module is exposed as `AyijeUI.QOL` and `ayijeUIQOL.module`, with its settings
available through `module.db` (also `ayijeUIQOL.db`). Add defaults in `Core.lua`
and start/stop feature behavior in the module's `Enable` and `Disable` methods.
Add controls in `AyijeUI_Options/Panels/QOL.lua` using the existing `ns.Opt` and
`ns.Config` helpers.
