# Working on FuzzyBar

- Comments say what the code does now and why it has to be that way. History
  (renames, review rounds, how a number was measured, when a screenshot was
  taken) goes in the commit message, not in comments or the README.
- Say a thing once. If a comment, the README and a test doc would all tell
  the same story, keep the one nearest the code that needs it.
- A number or list in prose ("crops to 33", "two writers") goes stale
  silently. Prefer stating the constraint; when you change code, reread the
  comments around it.
- Reuse before copying: the slot-table personalities run on
  `CustomPersonality.phrase`, and tests get UserDefaults from
  `scratchDefaults()`.
- Tests go in the file for the unit or feature they test, not in a file per
  review round.
- A new or renamed Swift file needs `xcodegen generate`;
  `Tests/BuildScriptTests` checks the project matches the disk.
- `Tools/check_archive.sh` is shared with other PlumpBug repos: change only its
  "this repo" block here.
- `docs/CODE_TOUR.md` follows one minute from the timer to the menubar and
  names functions; update it when one it names is renamed or moved.
