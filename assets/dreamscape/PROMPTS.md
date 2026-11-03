# Dreamscape image generation

Generated 2026-11-03 using the built-in image generation tool. No API/CLI fallback.
These are original generated game assets, not downloaded reproductions of paintings.

| Asset | Use |
| --- | --- |
| `afternoon_sky.png` | PanoramaSkyMaterial in every level |
| `porcelain.png` | Triplanar architecture, checker floor, enemies, tools and cast weight |
| `vacant_chair.png` | Framed in-world mural |

The following are the exact generation prompts. Outputs were copied unchanged into
this folder. Mipmaps are enabled in the checked-in Godot import settings.

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
