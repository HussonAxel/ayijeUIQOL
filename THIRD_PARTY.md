# Third-party references

`TokenAppearanceData.lua` is a snapshot of the installed RefineUI module
`Modules/Shared/TokenAppearanceData.lua`, generated there from TokenTransmogTooltips
data. Copyright (c) 2026 Enkiduke, MIT; see `RefineUI-LICENSE.txt`. The namespace is
adapted to ayijeUIQOL. RefineUI is not required at runtime.

Appearance ownership and token variant resolution follow RefineUI's collection
model: account-wide visual ownership, exact item context and faction. The native
upgrade/catalyst implementation uses the installed FunelQOL Midnight set catalogue
and native eligibility checks as behavioral references. Neither reference addon
nor TransmogUpgradeMaster is called or required at runtime.

`AppearanceSetSources.lua` contains factual client source IDs for 104 Midnight
season 1/2 class tier sets, extracted from the installed TransmogUpgradeMaster
`data.setSourceIDs` catalogue. This data snapshot fills missing native wardrobe
set-slot entries; no TransmogUpgradeMaster executable code or artwork is imported.

`DelveRatings.lua` preserves the user's twelve-delve story/time/grade catalogue
from the installed FunelQOL addon, including localized achievement criteria IDs
and aliases. Its ratings are user-supplied references. World-map entrance label
integration follows the installed RefineUI `Modules/Maps/InstancePins.lua`
approach (native pooled pins, deferred decoration), under the MIT notice above;
story matching follows FunelQOL's `DelveContent.lua`. Neither addon is required.

## Local appearance media

`Media/Local` contains byte-identical local copies of Pixels border/textures,
RefineUI `RefineBorder.blp` / `SmoothV2.tga`, and D1 from the user's FunelQOL media.
`manifest.json` records source paths and SHA256 hashes. Pixels/Ellesmere artwork
retains its original license and is excluded from Git; RefineUI media is covered
by `RefineUI-LICENSE.txt`. These copies are for the user's local installation,
and do not create a redistribution grant. No third-party font is copied.

`Media/CooldownBorder.tga` is a procedurally generated eight-slice border using
dark outer/inner lines and a grey rim, following the CDM-like profile described
by the user's FunelQOL `FrameBorders.lua`. Ayije artwork is referenced directly
from the required AyijeUI addon; Blizzard artwork uses client paths.

## Custom tracker providers and local catalogues

`TrackerProviders` adapts the user's FunelQOL content providers, with permission
in this task. `TrackerStore.lua`, `CustomTrackers.lua`, `TrackerInteractions.lua` and the AyijeUI options
replace FunelQOL's panel renderer, settings, theme and edit-mode integration.
No FunelQOL runtime, media, font or edit-mode library is required or imported.
`TrackerProviders/TokenAppearances.lua` retains the RefineUI collection/token
adaptation under the MIT notice in `RefineUI-LICENSE.txt`; its factual token data
is shared with this addon's existing `TokenAppearanceData.lua`.

`TrackerProviders/RareData.lua` is a local copy of FunelQOL's generated RareScanner
12.1.0.14 NPC position/loot tables. RareScanner is All Rights Reserved; this local
personal-use copy is excluded from Git and grants no redistribution rights.
`TrackerProviders/TeleportData.lua` is a local copy of the catalogue generated
from TeleportMenu v13.1 (Justwait); it retains the source restrictions and is also
excluded from Git. Their source/version headers are preserved. Neither source
addon is called at runtime.

`CurrencyCatalog.lua` and `RaidAchievementData.lua` retain factual Blizzard client
DB2 IDs and source comments from the user's FunelQOL catalogue (the achievement
snapshot is build 12.1.0.69933). Quest/weekly IDs, set IDs and other factual
cross-references retain provider comments. These are snapshots, not automatically
updated databases. `TrackerSavedPanels.lua` contains only the user's locally
recovered panel settings and per-character weekly memories; it is excluded from
Git. `tools/Import-FunelTrackers.py` reads existing saves without changing them.

`TrackerInteractions.lua` adapts the user's FunelQOL panel shortcut and snapping
behavior (four sides, three alignments, proximity preview and cycle rejection)
to AyijeUI movers and stable profile-owned panel IDs. It uses the native context
menu for direct content/row selection and does not load FunelQOL or LibEditMode.

`LegacyCompletionist.lua` and `LegacyCompletionistUI.lua` adapt the behavior of
RefineUI's Legacy Completionist Mode (MIT, Copyright Enkiduke; license copy in
`RefineUI-LICENSE.txt`): Adventure Guide loot scan with state restoration,
per-boss grouping, paging, auto-collapse and the private objective tracker
module. They were rewritten on ayijeUIQOL's own services and do not load or
require RefineUI at runtime.

`TrackerSkin.lua` adapts the objective tracker skin of RefineUI's Quests module
(MIT, Copyright Enkiduke; license copy in `RefineUI-LICENSE.txt`): header bar
geometry, the instance art cropping rules and the delve entrance art mapping. It
draws with AyijeUI's own border and bar helpers and does not load or require
RefineUI at runtime.

`GlobalAnchors.lua` extends the user's tracker anchoring behavior to AyijeUI's
native mover registry. Geometry rules follow the existing tracker adaptation;
identity, profile storage, protected-frame proxies and the native mover bridge
are implemented locally without FunelQOL or LibEditMode runtime dependencies.
