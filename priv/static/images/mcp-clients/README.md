# MCP client marks

Official publisher assets collected on 2026-10-09 for identifying clients in
Mmentum's MCP setup guide. These marks belong to their respective owners. They
are not Mmentum branding and do not imply partnership, sponsorship or endorsement.
No third-party icon packs, traced logos or placeholder artwork are included.

## Display

`-light.svg` means **on a light background**; `-dark.svg` means **on a dark
background**. Use the supplied variants, not a CSS color filter. Keep the aspect
ratio and built-in clear space; render with `object-fit: contain`, not cropping.

- Cursor: `cursor-light.svg` / `cursor-dark.svg`; publisher's 2D cube, dark
  `#26251e` / light `#edecec`. Do not invert these off-black/off-white brand colors.
- Visual Studio Code: `vscode.svg`; blue stable mark for both themes. Do not
  invert. Its brand guide requires clear space equal to 25% of the fish motif.
- Claude Code and Claude: share `claude.svg`, Claude's official
  `#D97757` symbol. Use unchanged on both themes; do not invert.
- OpenCode V2: `opencode-light.svg` / `opencode-dark.svg`; official two-color
  mark from the V2 repository branch. Do not invert.
- Codex: `codex-light.svg` / `codex-dark.svg`; official black/white OpenAI
  Blossom, an explicitly documented fallback below. These are monochrome, so
  inversion is technically suitable, but the supplied official variants avoid
  altering the files or their prescribed clear space.
- ChatGPT shares those official OpenAI Blossom variants.
- Gemini CLI: `gemini-cli.svg`; official full-color terminal icon with its
  built-in dark background, suitable on both themes. Do not invert or replace
  its gradient with current Gemini model colors.
- Amp CLI: `amp.svg`; official Amp app icon, cream wordmark on its built-in
  green background, suitable on both themes. Do not invert.
- Notion: `notion.svg`; official black mark with the publisher's white backing
  and outline, suitable on both themes. Preserve the backing; do not invert.
- Pi: `pi.svg`; the official multicolor Pi mark, unchanged on both themes.
- Other clients: no brand asset; retain the application's generic icon.

## Sources and usage limits

### Cursor

- Official brand page: https://cursor.com/brand
- Download: https://ptht05hbb1ssoooe.public.blob.vercel-storage.com/assets/brand/cursor-brand-assets.zip
- Archive members: `General Logos/Cube/SVG/CUBE_2D_LIGHT.svg` and
  `General Logos/Cube/SVG/CUBE_2D_DARK.svg`, respectively.
- The brand page provides these files to represent Cursor consistently and
  accurately and calls 2D the default logo treatment. Use the name “Cursor”,
  not “Cursor AI” or “Cursor Code”. No separate open-source redistribution
  license appears on the brand page; do not treat the assets as unrestricted.

### Visual Studio Code

- Official guidelines: https://code.visualstudio.com/brand
- Download: https://code.visualstudio.com/assets/branding/visual-studio-code-icons.zip
- Archive member: `visual-studio-code-icons/vscode.svg`.
- Microsoft permits the icon in documentation/tutorials about Visual Studio
  Code and links to its website. Do not use it to identify/promote Mmentum,
  imply association with Microsoft, combine it into another logo, alter it,
  or use the app/Insiders/vintage icons. The white alternate is allowed only
  when the blue mark lacks contrast; it is not needed for ordinary dark cards.
- Visual Studio Code, VS Code and its icon are Microsoft trademarks; all rights
  reserved. These are brand-use terms, not the VS Code source-code MIT license.

### Claude

- Publisher/product page: https://claude.com/
- Exact vector: https://claude.com/favicon.svg
- Brand terms: https://www.anthropic.com/legal/consumer-terms
- This is Anthropic's official Claude symbol, shared for Claude and Claude Code
  rather than a fabricated terminal logo.
- James reviewed Anthropic's logo terms and approved this integration's use on
  October 9, 2026. This records the project owner's approval, not an unrestricted
  redistribution license or an endorsement by Anthropic.

### OpenCode V2

- Official brand page: https://opencode.ai/brand
- Official V2 repository: https://github.com/anomalyco/opencode/tree/v2
- Pinned source commit: `229b422bd600df2a2b8d637fec5653dff779827f`.
- Light: https://raw.githubusercontent.com/anomalyco/opencode/229b422bd600df2a2b8d637fec5653dff779827f/packages/console/app/src/asset/brand/opencode-logo-light.svg
- Dark: https://raw.githubusercontent.com/anomalyco/opencode/229b422bd600df2a2b8d637fec5653dff779827f/packages/console/app/src/asset/brand/opencode-logo-dark.svg
- Repository license: https://raw.githubusercontent.com/anomalyco/opencode/229b422bd600df2a2b8d637fec5653dff779827f/LICENSE
- The repository supplies these brand files under its MIT license; preserve
  the notice below. The software license is not a trademark endorsement.

### Codex

- Product page: https://openai.com/codex/
- Official Codex extension listing: https://marketplace.visualstudio.com/items?itemName=openai.chatgpt
- Publisher's actual extension icon: https://openai.gallery.vsassets.io/_apis/public/gallery/publisher/openai/extension/chatgpt/latest/assetbyname/Microsoft.VisualStudio.Services.Icons.Default
- Official brand guide and usage terms: https://openai.com/brand/
- Vector download: https://cdn.openai.com/brand/OpenAI-Logos-2025.zip
- Archive members: `OpenAI-logos(new)/SVGs/OpenAI-black-monoblossom.svg` and
  `OpenAI-logos(new)/SVGs/OpenAI-white-monoblossom.svg`, respectively.
- **Sourcing limit:** no standalone official Codex app cloud/terminal mark was
  found in the public product pages or official Codex GitHub repository. Do not
  substitute an unofficial redraw. OpenAI's own Codex extension publishes the
  Blossom as its icon, so these official vectors use that verified alternative;
  they are not presented as the dedicated Codex app mark. Replace them only
  when a suitable standalone publisher app asset becomes available.
- Use only in direct relation to OpenAI services, exactly as provided, less
  prominently than Mmentum's own marks, and acknowledge ownership. Do not imply
  endorsement or incorporate the mark into Mmentum branding. The brand guide's
  limited, non-exclusive, non-transferable permission can be withdrawn and is
  not an unrestricted asset redistribution license.

### Gemini CLI

- Official brand kit: https://geminicli.com/brand-kit/
- Exact vector: https://geminicli.com/brandassets/gemini-cli-icon_full-color.svg
- Guidelines: https://geminicli.com/brandassets/gemini_cli_logo_icon_guidelines.pdf
- The guidelines explicitly describe the icon for websites where Gemini CLI
  is offered separately from its name, such as a marketplace. Do not alter
  the assets or gradients. The brand kit does not state an independent
  open-source asset redistribution license; Google retains its trademarks.
- The site currently notes the June 2026 transition to Antigravity CLI for
  unpaid/Google One users. This remains the requested Gemini CLI mark, not an
  Antigravity mark or a generic Gemini model sparkle.

### Amp CLI

- Publisher page: https://ampcode.com/
- Exact vector linked by that page: https://ampcode.com/app-icon.svg?v=4
- Terms: https://ampcode.com/terms
- The terms reserve Amp's trademarks, service marks and trade names to Amp or
  its affiliates. No separate public brand kit or unrestricted asset license
  was found. Keep this official icon unchanged and limited to identification;
  sourcing it does not establish permission for other promotional uses.

### Notion

- Exact source page: https://www.notion.com/
- Extracted the complete inline SVG in the header's “Notion – Home” link,
  preserving all three paths, viewBox, white backing and outline.
- Publisher color-token source: https://www.notion.com/_next/static/chunks/3nr739qv1y-ex.css
- Its `--tatami-color-black` is `#000`. The source's
  `var(--notion-logo-fill, var(--tatami-color-black))` was resolved to that exact
  value so the file renders independently in an `img` element. Removed only
  the page-specific root class; no geometry or brand colors changed.
- Publisher's published brand-usage page:
  https://notion.notion.site/Notion-s-brand-usage-guidelines-How-to-use-Notion-s-brand-in-your-marketing-689045e1761348f887a3c5c80295e00f
- That client-rendered page did not expose readable guidelines to this fetch;
  no broad redistribution permission was verified. Notion retains its marks.
  Review its current trademark guidelines before promotional or co-brand use.

### Pi

- Official publisher asset: https://pi.dev/logo-auto.svg
- Publisher repository: https://github.com/earendil-works/pi (formerly badlogic/pi-mono)
- The coding-agent README links this asset as the Pi logo. Copied byte-for-byte,
  preserving its viewBox, geometry, padding, and colors. No third-party redraw.
- The publisher repository uses the MIT license; no separate unrestricted
  trademark license was verified. This use identifies the Pi client only.
- Repository license: https://github.com/earendil-works/pi/blob/v1.1.0/LICENSE
- Retrieved October 9, 2026. SHA-256:
  `abd66e7868b2d24f0f0895f9237ee8a6dcb22337583b0dc54aeb595acecb4d6b`.

## File safety and fidelity

All vendored images are SVG, with no scripts, event handlers, external images,
fonts, links, stylesheets, animation or foreign HTML. `url(#...)` references
point only to definitions within the same file. The files have explicit colors
and do not rely on host-page CSS. Gradients, masks and shadow filters are the
publisher's own. Only Illustrator generator comments and Notion's host-page
dependency were removed. Geometry and the supplied viewBoxes remain unchanged.

## OpenCode MIT notice

MIT License

Copyright (c) 2025 opencode

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Pi MIT notice

MIT License

Copyright (c) 2025 Mario Zechner

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
