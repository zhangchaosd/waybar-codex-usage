# Icon asset provenance

`codex-official-favicon.png` is downloaded from the favicon used by the official
OpenAI Codex documentation page:

- Page: https://developers.openai.com/codex/
- Asset: https://developers.openai.com/favicon.png

`codex-mark-white.png` is a derived 16×16 transparent Waybar asset. The build
script removes the favicon's blue circle, preserves the OpenAI knot as an
antialiased alpha mask, converts it to white, scales the mark to 14×14, and
centers it on a 16×16 canvas:

```bash
./scripts/build_icon.sh
```

The OpenAI name and logo are trademarks of OpenAI. These brand assets are not
covered by this project's MIT license; use them in accordance with OpenAI's
brand guidelines.
