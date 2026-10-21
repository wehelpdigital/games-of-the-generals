# Default avatars

Cute cartoon portraits shown by `ui/widgets/AvatarView.gd` for players without a profile photo.
Each player gets one picked from their username (FNV-1a hash), so it is the same on every screen
and device.

All 24 are original art, drawn as vector shapes by `tools/avatars/generate_avatars.js` and
rendered to 256 px WebP. They use no third-party assets, so no credit or licence is needed.

```sh
NODE_PATH=<dir with puppeteer-core> node tools/avatars/generate_avatars.js [--only id,id] [--sheet out.png]
```

To add avatars, append them to the end of `AvatarView.DEFAULTS`. Inserting or reordering
entries would change which avatar existing players get.
