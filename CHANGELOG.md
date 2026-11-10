# Baddie Mon – Natro Macro OCR fork – Changelog

Natro Macro dev build "new-reset" (Natro v1.1.2) with OCR fixes for the Roblox font update, Ray's Auto Jelly
(and, in the full build, all of Ray's extensions) and the Baddie Mon StatMonitor.

**Versioning:** every update gets a new version, whoever makes it. The version is set in
`submacros/StatMonitor.ahk` (`version := "x.y.z"`) and shows as "Patch vx.y.z" in the Discord startup
report and on the line above the timestamp in every hourly report. Add each update to the top of this list.

- **x** (major): big rework or anything that changes how the macro is set up
- **y** (minor): new feature or a set of fixes
- **z** (patch): small fix

Builds: `NatroMacro-OCR-AutoJelly` (main: OCR + Ray's Auto Jelly), `NatroMacro-OCR` (OCR + all of Ray's
extensions). Each has its own GitHub upload set: `NatroMacro-OCR-fix-upload` (main branch) and
`NatroMacro-OCR-Rays-upload` (Ray branch). Every update goes into all four.

---

## v1.4.1 – patch number on the report
- Hourly report shows "Patch v1.4.1" on the line above the timestamp; startup report says "Version: Patch v…"
- Report footer shows the real Natro version again ("Natro v1.1.2")

## v1.4.0 – self-learning buff stacks, versioning
- Buff stack numbers (x2–x10) teach themselves: when no picture knows a number, two independent OCR reads
  of the same screenshot (whole buff bar + close-up) must agree; the number's look (white fill + dark
  outline, icon ignored) is collected and only trusted after 3 alike confirmations. Saved per PC in
  `settings/buff_digits_learned/`; a look that matches two different numbers is thrown away. Recovers
  stack reading after a font change, and on PCs that draw icons differently (the Win11 Home Haste issue).
  Log: `tools/OCR_debug/buff_learn_log.txt`
- Version number shown in StatMonitor; this changelog added

## v1.3.0 – honey reading reliability
- Suspicious honey readings (a jump bigger than recent real changes, or a drop) are read again and only
  kept if two reads agree; allows for honey climbing fast while converting balloons
- Quick picture-only honey reads every 12 s cross-check each minute's reading (agree = confirmed,
  disagree = recheck); no OCR, so buff checks aren't slowed
- Session start = first reading confirmed by a second read (was the median of the first 5 readings, which
  cut an early balloon convert out of Session Honey); never reset later
- Confirmed big jumps are trusted (first convert after starting with low honey counts in full); gaining a
  digit (999B → 1T) no longer counts as suspicious
- Hourly report: spike filter tolerance from the hour's typical change instead of 2% of total (missed
  mid-number misreads on big accounts), runs twice; the hour's last reading is checked too; a low reading
  is only a misread if the readings on both sides are high
- Honey spent is added back: Honey Earned / Session Honey show what was made, not what is left
- Every recheck and cross-check is logged in `tools/OCR_debug/honey_log.txt`

## v1.2.0 – Blooms
- Merged NatroTeam's Blooms branch: Blooms option on the Gather tab (collects blooms while gathering),
  petal objectives in Polar/Riley/Bucko quests (Mashed Blooms, Petal Tabbouleh, Petals...), new quest reader
- Quest reader reads the giver name and quest title with OCR first (its pictures are old-font text),
  pictures only as fallback

## v1.1.0 – reset / hive / cannon fixes
- Hive check after reset waits up to ~8 s for the "Make Honey" prompt instead of one frame after 3.5 s
- After a baseplate spawn it always walks to the Hive Slot and checks the prompt again (the spawn colour
  check often missed, which caused endless resets)
- Clear warnings: "Spawn not recognised…", "Hive prompt not found at hive slot X – check Hive Slot…"
- Debug dumps: `hive_fail` / `hive_fail_walk` (.png, .txt with OCR words or OCR error, `_full.png` of the
  whole window)
- Red cannon prompt read with OCR too (its picture is old-font text, so the macro ran past the cannon),
  in the main script and in path scripts

## v1.0.0 – baseline (handoff)
- GUI offset via OCR of the topmost "Pollen"/"Honey" label, saved per window size, bitmap fallback
- Inventory, buttons, prompts and quests (Polar, Brown, Black, Bucko, Riley) via OCR; `?finditem` via OCR
- Reset loop fixes (unset offsetY in nm_ConfirmAtHive), camera waits until still after turns
- Haste and Focus digit pictures x2–x10, OCR fallback, walking holds the last Haste value up to 20 s
- Honey: shape-based digit reader that learns per PC, remembered "Honey" label position, OCR backup,
  misread checks, spike filter
- StatMonitor: 7 backgrounds, hourly report on hour change, full-size PNG, retries + log, `?hr`, number
  names past Qi
- Field boosts (pine/blue flower/bamboo/snowflake) by colour count; pine colour corrected
