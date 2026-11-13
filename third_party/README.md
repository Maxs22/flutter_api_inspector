# Bundled inspector assets

The inspector bundles offline fonts; it makes no runtime font requests and does not change the host application's typography.

- Lucide 0.468.0, ISC: https://unpkg.com/lucide-static@0.468.0/font/lucide.ttf
  Glyph mapping: https://unpkg.com/lucide-static@0.468.0/font/lucide.css
- Inter 4.001 (git-66647c0bb), Google Fonts variable font, SIL OFL: https://github.com/google/fonts/tree/main/ofl/inter
- JetBrains Mono 2.211, Google Fonts variable font, SIL OFL: https://github.com/google/fonts/tree/main/ofl/jetbrainsmono

Source TTF SHA-256 checksums:

```text
Lucide:         0ff17e4ce16364d2dae72689336262960e7d5067cfcdb07ca283465a2a34af48
Inter:          29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031
JetBrains Mono: 48715a42ec242c21e9f02692891e147d022299a52e48d5e413e1a942193ffeda
```

Full upstream licenses are in `licenses/`. The distributed TTFs are subsets, not the full upstream distributions. Inter is instantiated at optical size 14 and weights 400, 500, 600, 700; JetBrains Mono at 400 and 700. Text subsets include U+0020–017F, U+2000–206F, U+2190–21FF, U+2713 and U+221E; unsupported scripts fall back to the host platform fonts.

To reproduce, download the sources above into `build/icons-work/`, install `fonttools` in a project-local virtual environment, instantiate each text font using `fontTools.varLib.instancer.instantiateVariableFont`, then subset with `fontTools.subset.Subsetter`. Lucide retains only the codepoints declared in `lib/src/overlay/icons.dart`. Total bundled fonts: 377,580 bytes (about 369 KiB).
