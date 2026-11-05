# Independent keyboard usability review

Target: http://localhost:3149/woods. Read-only visible-browser review on 2026-11-04. Server left running. No repository, implementation, raw HTML/index, hidden DOM text, evaluate APIs, source mutations, injection, axe, storage edits, subagents or watches used. Token entered through labeled sign-in form only. No mouse, wheel or touch input. No diagnostic locator-focus pass was performed.

## Result

Completed at 390×1000 first, then 640×1000, 960×1000 and 1440×1000 with carried learning. Read from visually revealed portions of the THIRD ROW of **Tables in this chunk**, not diagram/detail identifiers:

- Table: `active_storage_variant_records`
- Model: `ActiveStorage::VariantRecord`

This is qualified task completion by joining overlapping visible portions, not proof that either complete value fits simultaneously. No attempt was blocked. Initial views at every width failed to expose both complete identifiers without keyboard scrolling.

## Prioritized findings

1. **Moderate usability friction: horizontal value reading also shifts the outer table.** At 390, outer table focus plus four Right presses moved the columns (022→023). Third-row table value focus plus Right presses exposed the ending while shifting the outer table and clipping its beginning (025→026). Model value focus similarly exposed `VariantRecord` while clipping its beginning (029→030). The same behavior recurred at 640 (037→038,039→040), 960 (047→048,049→050) and 1440 (056→057,058→059). Readers must remember and join fragments. This is observed behavior, not an implementation diagnosis.
2. **Moderate discoverability friction: value region versus link focus is subtle.** Extra stops have blue rounded outlines; adjacent links have underline/purple focus. I initially interpreted the third table value-region stop as a link after seeing outer-table motion. Shift+Tab and forward Tab revealed separate stops. The visible “↔ Scroll value if clipped” cue suggests horizontal movement but does not explain Tab sequencing, arrow keys, or simultaneous outer movement. I did not activate identifier links or use detail pages.
3. **Low friction: ERD is hidden in a menu at 390/640.** The menu icon is reachable by the first Tab; Enter reveals explicit ERD navigation, reachable by four more Tabs. At 960/1440 ERD is visible directly in the header and reachable by seven Tabs from the fresh page. Discovery succeeded.
4. **Clipping persists on desktop.** Even at 1440 the requested table/model columns clip these identifiers (054), requiring the same value-region navigation. More viewport width did not remove the reading task.

## Attempt record and learning

390 first-reader attempt: 001 sign-in visibly offered Token and Open session; 002 Status had menu icon and no visible ERD. Tab focused menu (003); Enter opened navigation (004); four Tabs focused ERD (005); Enter opened Schema (006). Schema summary and diagram suggested content below; PageDown revealed Tables in this chunk and clipping cues (007). First Tab returned to header menu (008). Twelve more Tabs reached copy Mermaid (020); four reached diagram region (021); one reached outer table (022). Four Rights moved outer table (023). Five Tabs reached second model link (024); one reached third table value-region (025). Four Rights exposed table suffix (026). Shift+Tab returned to second model link (027), then two Tabs reached third table link (028), then one reached third model value-region (029). Five Rights revealed model suffix (030). Visible prefixes and overlapping suffixes yielded both complete identifiers. Initial interpretation of value-region focus was mistaken; corrected through visible focus changes, without DOM inspection.

640 repeat, carrying menu/ERD, PageDown and value-region learning: reset to Status (031), Tab/Enter opened menu (032–033), four Tabs focused ERD (034), Enter and PageDown reached table (035–036). Twenty-four Tabs from fresh Schema reached third table value region (037); four Rights exposed suffix (038); two Tabs reached model region (039); five Rights exposed suffix (040). Both read by joining visible portions. No independent first-user claim.

960 repeat, carrying all prior learning: Status showed ERD directly (041); seven Tabs focused it (042); Enter and PageDown revealed table (043–044). Sidebar reduced available table space. Thirty-three Tabs reached first-row foreign-key region (045); four more reached third table link (046). Shift+Tab reached its value region (047); four Rights exposed suffix (048); two Tabs reached model region (049); five Rights exposed suffix (050). Both read by joining visible portions. The focus sequence differed from 640; learned counts did not identify the target automatically.

1440 repeat, carrying all prior learning: Status (051); seven Tabs focused visible ERD (052); Enter and PageDown revealed table with both values clipped (053–054). Thirty-six Tabs reached third model link (055). Three Shift+Tabs reached third table value-region (056); four Rights exposed suffix (057); two Tabs reached model region (058); five Rights exposed suffix (059). Both read by joining visible portions.

## Evidence and limits

Native PNGs 001–030 are 390×1000; 031–040 are 640×1000; 041–050 are 960×1000; 051–059 are 1440×1000. PNG headers verified all 59 against the configured CSS viewport dimensions; deviceScaleFactor=1. Key screenshots were visually inspected at native resolution, with readable crisp text and no apparent unfinished repaint. No image resizing or sharpening. Script waits 350ms after commands; it does not independently certify font-loading completion. Screenshot files preserve each recorded command's end state; some repeated Tab/arrow sequences were issued as batches, so intermediate focus stops were not individually inspected. This limits precision about every intervening focus stop. Claims concern observed endpoints and rendered text only.

Shared T3 Preview status initially unavailable; open succeeded, but two consecutive snapshots each failed: “Preview snapshot failed: Preview automation snapshot timed out after 15000ms.” Closed own Preview tab and used permitted native headless Google Chrome with Playwright-core. First driver launch had closed stdin and was restarted with a PTY before sign-in; its own idle browser was closed during cleanup. Main browser closed after review. No other browser or server was closed.

Parent-supplied provenance, NOT independently verified: Map runtime 267fe0928399a0dd6e6b95b6a325af0d19eac80a; head 1f7b1ed417f75e2bf1e6a3ba514b368784d5aba1 differs only evidence; Woods 237ca7c547555437cd5d596b9a5c1d1d963cfa71; testbed c6dc2c2e14fc857f0c9b12883434a5a548dd0af2 / base e6c2fdd218b15537d4e962597c2e01628f3b325e; Rails 8.0 / Ruby 3.3.1, gen3 normal extracted index. UI status displayed gen3 and compatible versions, but no revision audit was performed.

Engineering browser simulation only. No actual 200% zoom, physical device, human acceptance, screen-reader assessment or axe claim. Human first-reader comprehension, comfort and reliable recall of fragments remain unknown. Later widths are repeats by one increasingly informed reviewer.

## Committed capture index

- 390 × 1000: [001](001.png), [002](002.png), [003](003.png), [004](004.png), [005](005.png), [006](006.png), [007](007.png), [008](008.png), [009](009.png), [010](010.png), [011](011.png), [012](012.png), [013](013.png), [014](014.png), [015](015.png), [016](016.png), [017](017.png), [018](018.png), [019](019.png), [020](020.png), [021](021.png), [022](022.png), [023](023.png), [024](024.png), [025](025.png), [026](026.png), [027](027.png), [028](028.png), [029](029.png), [030](030.png)
- 640 × 1000: [031](031.png), [032](032.png), [033](033.png), [034](034.png), [035](035.png), [036](036.png), [037](037.png), [038](038.png), [039](039.png), [040](040.png)
- 960 × 1000: [041](041.png), [042](042.png), [043](043.png), [044](044.png), [045](045.png), [046](046.png), [047](047.png), [048](048.png), [049](049.png), [050](050.png)
- 1440 × 1000: [051](051.png), [052](052.png), [053](053.png), [054](054.png), [055](055.png), [056](056.png), [057](057.png), [058](058.png), [059](059.png)
