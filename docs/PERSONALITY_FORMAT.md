# FuzzyBar personality files

A `.fuzzybar` file is a personality you write yourself: every word the
menubar shows, in a plain text file. Double-clicking one opens it in
TextEdit.

## Making one

1. In FuzzyBar's Preferences, choose **Save as Template…**. It saves the
   personality you're using now and opens the file in your text editor.
   Spoken and Vague work differently, so choosing either one saves Classic
   instead.
2. Change the words after each label, keep the labels, and save.
3. Choose **Import…**, or drop the file anywhere on the Preferences window.
   It appears in the Personality picker below the built-in ones.

To change it later, edit the same file and import it again: a file whose
name line matches one you already have, ignoring case, replaces it.
[`Examples/Pirate.fuzzybar`](../Examples/Pirate.fuzzybar) is a complete one.

## What's in the file

```
name: Pirate
format: {phrase} {hour}, arr
next hour from: :35

:00  smack on
:05  a wee bit past
:10  ten past
…
:55  nigh on

12  twelve
1   one
…
11  eleven
```

Blank lines, and lines starting with `#`, are ignored, so templates carry
their instructions as `#` notes. The order of the lines doesn't matter, but
each label can appear only once. `name`, `format` and `next hour from` are
the only settings, in any case; any other is reported as a mistake.
Everything after a label is the words, exactly as written: apostrophes,
commas and curly quotes need no escaping.

| Line | Required | What it is |
| --- | --- | --- |
| `name:` | yes | The name in the picker. |
| `:00` to `:55` | yes, all twelve | What the minutes say. |
| `12`, `1` to `11` | yes, all twelve | The hour names. Or `0` to `23`: see below. |
| `format:` | no | How the two go together. Needs `{phrase}` and `{hour}`. Default `{phrase} {hour}`. |
| `next hour from:` | no | The minute from which the hour named is the next one, `:05` to `:55` (the colon is optional). Default `:35`. |

### How a time is read

Each minute line covers the five minutes around it: `:05` is 3 to 7 past,
`:10` is 8 to 12 past, and so on. `:00` covers 0 to 2 past, and `:55` runs
on to :59, so it's the "almost" line: 8:58 is still "nigh on nine", never
"smack on nine" too early.

From `next hour from` on, the hour named is the next one: with `:35`, 8:35
is "twenty-five 'fore nine". German says "fünf vor halb neun" at 8:25, so
it uses `:25`.

Twelve hour lines are used for the morning and the evening. If they should
differ, like "nine am" and "nine pm", or 24-hour styles like "2100 HOURS",
write 24 lines from `0` (midnight) to `23` instead. Any `0` or `13` to `23`
line makes the file a 24-hour one, which then needs all 24.

`format` puts the two together, so a language that says the hour first can
use `{hour} {phrase}`. Anything else in it, like `, arr`, is kept as written.

## Things to know

- **Plain text only.** If TextEdit shows a ruler and fonts, choose
  Format > Make Plain Text before saving. FuzzyBar says so if it gets rich
  text.
- **Mistakes are reported by line,** for example *Line 14: :07 isn't one of
  the minutes* or *The file needs a line for :40.*
- **Length.** On MacBooks with a notch, a long reading can end up behind
  it. FuzzyBar imports long ones anyway, but says which reading is longest
  and how many characters it is.
- **Special times** still win: at a special time, and at the first minute
  of the year, the menubar shows that instead.
- **Removing** one goes back to the built-in personality you had before.
- **Where it's kept.** FuzzyBar copies the contents into its preferences
  when you import, so moving or deleting the file afterwards changes
  nothing. It reads only files you pick or drop, and writes only where you
  save a template.

## Sharing

The files are yours to share. FuzzyBar doesn't host or list any: whatever a
file says, you wrote it or got it from someone else.
