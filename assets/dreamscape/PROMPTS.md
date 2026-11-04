# Campaign environment image generation

Generated 2026-11-03 and 2026-11-04 using the built-in image generation tool.
Original game assets, copied unchanged into this folder, with mipmapped imports.

| Asset | Current use |
| --- | --- |
| `alpine_sky.png` | Cold starting areas and highlands |
| `alpine_slate.png` | Stone, mountain and snow materials |
| `nightmare_sky.png` | Foundry sky and magical suitcase windows |
| `afternoon_sky.png` | Prepared Spillway sky |
| `porcelain.png` | Ceramic architecture, enemies and tools |
| `vacant_chair.png` | Framed mural in surreal regions |

The following are the exact generation prompts.


## alpine slate — 2026-11-04

```text
Use case: game-texture. A seamless tileable square diffuse albedo texture of rough blue-gray slate and granite for a stylized hand-painted fantasy MMORPG mountain environment. Large irregular stone planes, chipped edges, dark angular fissures, slate layering, sweeping painterly cool-gray brush strokes, occasional pale weathered edges, subtle mottled variation. Broad readable shapes at game distance, details in the cracks, soft baked painterly occlusion but no hard directional light, no cast shadows. Restrained palette of desaturated steel gray, blue slate, pale gray accents. Material texture only, orthographic flat surface, evenly lit. Not photographs, not smooth marble, not ceramic, not a regular brick grid, not pebbles, no snow, no moss, no neon, no text, no border. All four edges tile seamlessly. Production game material, high detail but exaggerated hand-painted forms.
```

## alpine sky — 2026-11-04

```text
Use case: game-texture. Create an original seamless equirectangular 2:1 panorama sky texture for a cold alpine fantasy videogame. A crisp steel-blue and pale ice-blue winter sky above a frozen mountain region, with sweeping sculptural white and blue-gray snow clouds, scattered wisps, distant cold haze near the horizon. Hand-painted stylized fantasy environment art with confident broad brushwork and subtle layered painterly transitions, readable cloud masses and quiet negative space, grounded and inviting, reminiscent of classic richly painted fantasy MMO environments. Midday, cold diffuse lighting. No orange sunset, no pink, no neon, no psychedelic elements, no lightning, no explosions, no stars. Horizon exactly at half height; upper hemisphere has the interesting clouds; lower hemisphere gradually becomes pale blue-gray atmosphere. Full 360-degree longitude panorama, left and right edges must join seamlessly, avoid detail at the poles. Sky only: no land, no trees, no mountains, no buildings, no sun disc, no text, no borders, no logos. This is a production game sky texture, not a scene mockup.
```

## sky

```text
Use case: stylized-concept
Asset type: seamless equirectangular sky panorama texture for a 3D absurdist dreamscape game, 2:1 landscape.
Primary request: a hand-painted sky of an impossible quiet afternoon, vast faded petrol teal and celadon upper atmosphere, luminous apricot ivory horizon, long sculptural cream cumulus cloud banks, faint dusty rose undersides. Evoke uncanny metaphysical painting, matte gouache and soft oil glazing, palpable stillness and beautiful subtle grain. Upper two thirds open sky with a few widely separated long cloud islands; lower third pale mist and a soft darker celadon nadir. The panorama is sky only, no ground scene.
Composition: full 360 degree longitude equirectangular environment map, left and right edges match, horizon at vertical midpoint, avoid pinching at poles. Clouds occupy the mid latitudes, no giant central focal object. Warm diffuse afternoon.
Constraints: no buildings, no text, no letters, no sun disc, no stars, no eyes, no objects, no watermark, no borders. Restrained colors, no neon or psychedelic swirls. This is an actual in-game sky texture, not a mockup.
```

## porcelain

```text
Use case: stylized-concept
Asset type: tileable square albedo material texture for architecture in a 3D absurdist dreamscape game.
Primary request: aged ivory porcelain and chalky lime plaster with delicate hairline crazing, rubbed pale warm grey patina, tiny faint celadon speckles and very subtle brush marks. The texture should feel like an antique ceramic object enlarged to the size of a building. Beautiful restrained material realism with painterly softness.
Composition: orthographic straight-on macro surface, perfectly even diffuse illumination, seamless repeating on all four edges, no directional shadows, no bevels, no perspective. Off-white and pale grey only so it can be tinted by the game material. Low contrast and medium fine grain, a few branching hairline cracks, no big dark cracks.
Constraints: full bleed texture only, no objects, no tile grout grid, no writing, no borders, no watermark, no dramatic lighting. Square image.
```

## mural

```text
Use case: stylized-concept
Asset type: square surrealist mural texture, displayed on enormous framed billboards inside an absurdist 3D game.
Primary request: an exquisitely painted official portrait of a vacant chair. A single antique bentwood chair floats horizontally through a perfectly circular hole in a large pale pink egg. The egg stands alone on a small cream checkerboard plinth in a vast quiet celadon sea. A tiny brass key dangles above the empty seat, connected to nothing. Distant dark plum doorway on the horizon and a long impossible shadow. It should feel formally solemn, tender, quietly funny, and existentially inexplicable.
Style: original metaphysical oil painting with restrained gouache grain, precise clear contours, sculptural simplified volumes, dusty rose, ivory, celadon, antique ochre and plum. Uncanny scale, understated dream logic. No psychedelic aesthetic.
Composition: one clean centered scene, calm negative space, straight-on square painting with no frame (frame is built in 3D), readable from far away. No human figures.
Constraints: NO TEXT, no letters, no logo, no watermarks, no typography, no border. Full bleed painted illustration.
```


## nightmare sky — 2026-11-04

The built-in image generator created this replacement after the owner requested a
horror trance party palette. The PNG is unchanged; motion is supplied in-game by
`shaders/nightmare_sky.gdshader`.

```text
Use case: stylized-concept
Asset type: seamless 2:1 equirectangular sky panorama for an absurdist psychedelic horror videogame.
Primary request: an overwhelming midnight nightmare rave atmosphere. The sky is a deep almost-black aubergine void with enormous sculptural violet storm clouds, lurid electric-magenta undersides, poisonous acid-green light seeping out of narrow breaks, and thin unnerving cyan auroral ribbons. The clouds feel organic and wrong, like folds inside an impossible cosmic organism. Some distant cloud rings resemble empty sockets, ambiguous shapes only. A cinematic underground trance party transplanted to the end of the universe. Beautiful but distinctly ominous and alien.
Composition: full 360 degree longitude panorama, left and right edges match, horizon exactly halfway down, upper hemisphere detailed clouds at mid latitudes with dark negative space at zenith, bottom hemisphere descends to black-purple mist. Strong silhouettes, restrained areas of neon against very deep darks, readable cloud structure. No sun, no daylight, absolutely NO warm sunset, no peach, cream, beige, orange or gold. Not a flat rainbow gradient. No ground objects or architecture.
Style: dense painterly oil and airbrush, uncanny surrealist horror, rich inky shadows and phosphorescent cloud rims, analog psychedelia. This is the actual game sky texture, no UI, no border, no writing, no logo or watermark. Landscape 2:1.
```
