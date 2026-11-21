# Model quality reference (owner-supplied)

**Status: images supplied by the owner on 2026-11-22.** Model (MODEL) tasks may run. Decision record: DECISION_LOG 2026-11-22 "Art quality references".

## The images
There are six images: three the owner likes and three the owner dislikes. They live in this folder as `liked-1..3.png` and `disliked-1..3.png`.
- **They are not committed.** The repository is public and the images come from the web with an unknown licence (`.gitignore`).
- **Original source:** the owner's folder `OneDrive\Bilder\4 referenz bilder` (`mag ich 1..3`, `mag ich nicht 1..3`).
- **If the PNGs are missing** on another machine, the descriptions below are binding.

| File | Shows | Owner verdict and reason |
|---|---|---|
| liked-1 | Deciduous tree with a canopy of 10–15 rounded, softly faceted blobs and a smooth curved trunk with 2–3 branches. Fresh, natural greens, warm brown, soft light. | **Liked – the target level.** Clearly low-poly, but full and carefully shaped; not too simple, not too detailed. |
| liked-2 | Very simple conifer: 3 stacked, flat-shaded tiers on a straight square trunk. | **Liked – the minimum level.** Simple, clean and readable. Enough for small or rarely seen things. |
| liked-3 | Faceted low-poly character (a Viking with a sword), with deliberate facets, a warm harmonious palette and expressive proportions. | **Liked – the level for models players see all the time.** More shape detail and care, still low-poly. |
| disliked-1 | Tree with a canopy of many jagged, splintered leaf shards and painted bark strokes on the trunk and roots. Very saturated lime green. | **Disliked – too much.** Noisy, busy silhouette and texture detail break the clean low-poly look. |
| disliked-2 | Tree with 4 loose, unshaded blobs on thin stick branches, in pale flat colours. | **Disliked – too little.** It looks unfinished and cheap, with no volume and no care. |
| disliked-3 | Realistic tree with photo-like leaf cards. | **Disliked – wrong style.** Realism and alpha leaf textures do not fit the stylised low-poly world. |

## Quality tiers
Every model gets one tier, set by the planner in the plan. If in doubt, take the higher tier.

**Tier A – often or long in view.** The target is liked-3 and liked-1. Covers:
- the sales stand and every HQ tier, the checkout and the receiving bays
- customer cars, the supplier truck and buildings on the map
- the Christmas trees for sale
- the big tree on the village square and anything else the camera passes daily
- Expected: a characteristic silhouette, readable from a distance and up close, with 2–3 levels of shape detail (main mass, secondary forms such as roof edges, wheel arches or window frames, a few accents). The facets are deliberate, and the colours stay within one palette with light and shade variants.

**Tier B – small, distant or rare.** The minimum is liked-2. Covers:
- background trees and forest, rocks and fences
- small decor, signs, pallets and crates
- Expected: a simple, clean form with a clear silhouette and no visible gaps. This is never worse than liked-2.

## Look: follow the reference game, but not identically (owner decision 2026-11-22)
- **What to follow:** the reference game's style direction for every model type: how its stand, truck, cars, bays, trees and buildings are built, their proportions and dimensions, the arrangement of the parts and the colour mood. A player should recognise the type immediately.
- **What stays ours:** never the same model.
  - Our own silhouette details, palette values, decoration and signs.
  - No logos, names, text or textures from the reference game.
  - At least the form of the main mass, or the roof, or the decoration must differ visibly.
- **Sources for the look:**
  - the observations in [REFERENCE_GAME_LIVE_TEST.md](../../REFERENCE_GAME_LIVE_TEST.md)
  - the reference screenshots under `docs/references/roblox-game/`, if they are available locally (see "Für den Owner am PC" in `docs/CLAUDE_BACKLOG.md`)

## Review checklist
The modeler checks every new model against this list before integration. A model passes only if every item passes, and it reports each item with evidence (a Studio screen capture where the MCP supports it).
1. **Style:** stylised low-poly with deliberate facets. No realistic textures, no alpha leaf cards, no painted brush-stroke detail (disliked-1, disliked-3).
2. **Detail level:** matches its tier. Tier A reaches liked-1 and liked-3; tier B reaches at least liked-2. Never as bare as disliked-2 and never as noisy as disliked-1.
3. **Silhouette:** closed and readable as the model type from a distance, with no loose stick parts, no shard edges and no gaps.
4. **Colour:** our own winter palette. Saturated but natural, with no neon lime. Each material has a light and a shade variant, and the colours stay harmonious across the scene.
5. **Proportions and scale:** the player is about 5 studs tall, doors are 4 × 7, counters 3.5–4 high. The model fits the type's dimensions in the reference game.
6. **Reference look:** the type is recognisable as in the reference game, but it is visibly its own model (see the rules above).
7. **Technical:** pivot and name are correct, collision fits, the model runs on mobile, and it meets the definition of done in `docs/MODEL_INTEGRATION.md`.
