# Ketik Saji — replace guided tutorial with one panel

Latest coordinator instruction · 19 November 2026 (WIB)

This is the active final tutorial instruction and supersedes older guided onboarding and the v005 tutorial proposal. The coordinator deferred ZIP generation on the tutorial-only turn; it is now incorporated into this explicitly requested final handoff. The original standalone addendum is preserved under sources/.

## Required change

Remove the guided tutorial sequence. Replace it with one explanatory panel using the exact player-facing text below. Use the existing supplied wooden panel/button resources and Grape Soda. No additional tutorial artwork is needed.

Remove or disconnect the sequence's automatic step progression, required actions, arrows/highlights, guided popup chain, and gameplay gates that depend on tutorial completion. Keep normal game controls working independently of the panel. A Help entry should reopen this same panel rather than restart the old sequence. Do not remove unrelated story material merely because it is adjacent to tutorial code.

The coordinator specified the text and single-panel presentation. Entry timing remains an integration detail: reuse an established appropriate opening point, or the earlier proposal of first Planning plus reopening from Help. Reading help during Serving should use the existing Pause path so gameplay does not continue behind the instructions. Closing the panel must not advance the day, start service, move the player, or complete a guided step.

## Exact player-facing tutorial text

Keep this content and wording. Render Markdown headings, emphasis, bullets, and inline command highlighting as UI formatting; do not show literal Markdown delimiters or the line-break backslash. Extra blank lines in the source are spacing, not additional content.

<!-- PLAYER_TEXT_START -->

# CARA MAIN

**KLIK & KETIK**

- Klik lantai untuk berpindah, klik objek untuk berinteraksi.
- Ketik perintah yang muncul. Tidak perlu tekan Enter!

**SEBELUM BUKA**

- Pilih menu, beli bahan, dan tambah peralatan.
- Ketik `buka` untuk mulai berjualan!

**SAAT BERJUALAN**

- Siapkan bahan, masak, lalu sajikan pesanan sebelum pelanggan kehabisan kesabaran!
- Ketik `saji` untuk mengantar makanan.
- Ketik `bersihkan` untuk membereskan meja, lalu `cuci` untuk mencuci piring.
- Pesanan online bisa diterima dengan mengetik `terima`. Awas, ada batas waktunya!

**TARGETMU**\
Kumpulkan cukup uang sebelum hari ke-7 berakhir!

**Selamat berjualan, semoga nggak ikut matang!**

<!-- PLAYER_TEXT_END -->

## Panel and formatting

Use one board with `CARA MAIN` as the strongest heading, followed by the three instructional groups, the target line, and the closing joke. Keep the bullet structure and emphasize the four section headings. Highlight `buka`, `saji`, `bersihkan`, `cuci`, and `terima` consistently without requiring the player to type them to dismiss help.

Use dynamic Grape Soda text, not newly generated title/paragraph image assets. The font delivery has one face; use size, color, and restrained emphasis rather than requesting nonexistent bold font files. Keep enough inner padding for the wooden border, wrap long bullets at word boundaries, and reserve separate space for a visible `Tutup` or established equivalent button. All text remains inside the board. Button text is control chrome, separate from the exact tutorial copy.

Preserve the coordinator's in-game attribution decision: no font attribution or mandatory credits UI on this panel. It is already on itch.io according to the coordinator.

## Mandatory fit verification by the implementation agent

**The agent must verify the rendered panel in the actual game. Measuring character count or passing headless logic tests alone is insufficient.**

1. Load the actual imported Grape Soda resource, the real panel art, and the exact text above. Check wrapping, line height, section spacing, bullet indentation, and close-button placement together.
2. Check the normal game window, the 1600 × 900 design-reference size, and the project's actual supported smaller/minimum window size. Record the resolutions tested; do not assume that logical viewport dimensions are the same as physical window dimensions.
3. Confirm the full content fits visibly inside one panel, including the closing joke and the close button. No clipped lines, overlap, off-screen controls, missing glyphs, or text under the wooden border/footer.
4. Adjust panel dimensions, content padding, group gaps, wrapping width, and sensible font sizes as needed. Keep the text comfortably readable. Do not delete/rewrite sentences, compress text horizontally, or shrink it into illegibility to claim it fits.
5. The requested target is the entire text readable on this single panel. Do not silently split it into tutorial pages or make scrolling the default substitute for fit. If the actual minimum supported size cannot display it readably, record the concrete resolution and layout issue and report the needed compromise.
6. Verify mouse and keyboard focus cannot activate the world behind the panel, and that closing/reopening it never resumes an old guide sequence. If help is opened from Pause, closing help returns through the existing pause behavior without unexpectedly resuming timers.
7. Cross-check that the stated commands match the current implementation. A genuine mismatch must be fixed or reported; do not silently change this coordinator-authored copy to match stale tutorial behavior.

Before the next relevant push, update `/docs/PROJECT_STATUS.md` with the guided sequence's removal, the single-panel implementation, the tested resolutions, font resource used, actual fit/readability observations, and any remaining issue. Capture rendered evidence for the developer/coordinator's review according to the project's usual workflow.

## Source attribution and delivery limit

This cleaned brief derives directly from the coordinator's latest message and preserves their tutorial text. The user also explicitly stated: “make sure that the agent verifies this so that it actually fits on the panel” and “you dont need to update the zip file for this pass.”

This addendum records the request. It does not claim that the repository was modified, the tutorial was already removed, or the actual in-game panel was fit-tested by the handoff preparer.
