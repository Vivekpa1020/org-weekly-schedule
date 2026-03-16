![Version](https://img.shields.io/static/v1?label=org-weekly-schedule&message=0.1.0&color=brightcolor)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Emacs](https://img.shields.io/badge/Emacs-27.1+-purple.svg)](https://www.gnu.org/software/emacs/)



# org-weekly-schedule

Build weekly time-block schedule tables inside Emacs org-mode because of the strong support for customizable and flexible tables.


## Overview

`org-weekly-schedule` generates Org mode tables that map activity codes
(A, B, C, ...) to 90-minute time blocks across the days of the week.
You define reusable **day templates** — named patterns like
"research-heavy" or "teaching-day" — then stamp them into a schedule
grid one column at a time.

The package operates in three layers:

| Layer          | Function                                  | Purpose                                     |
|----------------|-------------------------------------------|---------------------------------------------|
| Scaffold       | `org-weekly-schedule-insert`              | Insert the base table (Time column only)    |
| Column stamp   | `org-weekly-schedule-append-day`          | Append one day column from a template       |
| Week builder   | `org-weekly-schedule-build-week`          | Insert scaffold + stamp all days at once    |

## Problem addressed

This project was inspired by the idea that you can build a weekly template to streamline the planning process.
While academics do have many projects they are involved in, they do not have to make as many strategic decisions in a given day as CEOs do.
The planning techniques appropriate for the business world are not as appropriate for academia.
I was getting tired of spending 60 to 90 minutes a day planning, when many days were similar and could be streamlined with a template approach.
I suspect there are also many similarities to academic workflows in knowledge work in the private sector.

The idea of a weekly template that distinguishes between different kinds of days comes from Cal Newport.
I had previously developed a similar weekly schedule using the format shown below, but I had not considered how my days of the week actually differ in nature.
I had tried to set every day of the week as a research day, with different kinds of writing best done at different times, depending on my energy levels.
The variation in the nature of my days wreaked havoc on my straight-jacket approach.

In an episode on his YouTube channel, Cal distinguishes class days from research days.
On his research days, he goes deep into writing and avoids any meetings.
On his class days, he delivers his lecture in the morning and then spends the afternoon doing administrative chores.
I was able to identify about 15 other kinds of days in my yearly schedule, including days traveling to various kinds of meetings and days at those meetings.
I also have days when I conduct experiments and collect data.
I have several days a year where I attend dissertation defenses and commencement ceremonies that make a dent in my day.
These activities put constraints on the time available for writing.

By developing a template for those days, you can predetermine what kind of writing you'll do and when.
If you have to apply a very similar schedule to ten days a year, it is a waste of time to regenerate that schedule ten times.
It's faster to use a template and then tweak it to meet the specific needs of the day.

This software tool can be customized to meet your specific needs regarding the template days.
You can expand the number of template days to meet your specific needs.
You can also change their nature.
I see the letter codes A and B for two different major writing projects, but you can expand that number of codes to meet your needs if you're trying to make progress on multiple projects in parallel.
If you're a programmer, you might be working on one or two major projects.
You could treat your programming projects the way I treat my writing projects.

Cal Newport also talked about developing a set of policies to follow when planning your week.
For example, he protects his writing time, by which he means the time he spends on generative writing.
He tries to do a couple of hours every day.
He will not schedule a meeting during that block of time.
However, if he can't do otherwise and has to attend that meeting, then he has a policy of going to a certain location, like a coffee shop, and carrying out that generative writing for the next 90 minutes.
He also blocks off certain days when he will not participate in any meetings so he can build momentum on his research projects.

Another policy you'll need to develop is what to do if you get a late start on your schedule.
For example, you can see that I have 4 a.m. listed as the starting point for my generative writing.
Due to mismanagement of my attention the prior night, I might actually be more excited about Project D.
I may feel that I need to do some generative writing about that project D, even though it was not scheduled.
I may spend some generative writing time working on project D when I am scheduled to work on project A.
The upside to working on project D is that I have cleared my mind of my thoughts about that project so that I have freed up space for project A.
I have also warmed up my generative writing engine, so I should have an easier time engaging in project A.
However, I have also consumed some of my generative writing time, which is limited to 4.5-5.5 hours per day.

How am I going to compensate?
If I do not compensate, Project A will fall behind schedule.
I should have a policy written down in an accessible document for such situations, so I don't have to reinvent the decision every time I encounter it.
One potential solution is to tack on additional generative writing time on a light writing day.

## Future plans

Develop a Markdown version written in Python.



## Requirements

- Emacs 25.1 or later
- Org mode 9.0 or later (ships with Emacs 26+)

## Installation

### Manual

Clone or download this repository, then add the directory to your
`load-path`:

```elisp
(add-to-list 'load-path "/path/to/org-weekly-schedule")
(require 'org-weekly-schedule)

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c t i") #'org-weekly-schedule-insert)
  (define-key org-mode-map (kbd "C-c t w") #'org-weekly-schedule-build-week)
  (define-key org-mode-map (kbd "C-c t a") #'org-weekly-schedule-append-column)
  (define-key org-mode-map (kbd "C-c t d") #'org-weekly-schedule-append-day)
  (define-key org-mode-map (kbd "C-c t h") #'org-weekly-schedule-add-date-header))
```

### use-package

```elisp
(use-package org-weekly-schedule
  :load-path "/path/to/org-weekly-schedule"
  :bind (:map org-mode-map
         ("C-c t i" . org-weekly-schedule-insert)
         ("C-c t w" . org-weekly-schedule-build-week)
         ("C-c t a" . org-weekly-schedule-append-column)
         ("C-c t d" . org-weekly-schedule-append-day)
         ("C-c t h" . org-weekly-schedule-add-date-header)))
```

## Quick start

1. Open an Org buffer.
2. Run `M-x org-weekly-schedule-build-week`.
3. Enter a start date when prompted (e.g. `2026-03-16` for Monday
   March 16) or press RET to skip the date header.
4. At each day prompt, type a template name (`research-heavy`,
   `balanced`, etc.) or press RET to skip that day.
5. A complete schedule table appears at point.

The result looks like this (with a date header):

```
| Day           | M  | Tu | W  |
| Date          | 16 | 17 | 18 |
|---------------+----+----+----|
| Time          | M  | Tu | W  |
|---------------+----+----+----|
| Generative:   |    |    |    |
| 04:00-05:30   | A | B  | A  |
| 05:45-07:15   | A | B  | B  |
| 07:30-09:00   | A | A  | A  |
|---------------+---+----+----|
| Rewriting:    |   |    |    |
| 09:15-10:45   | A | A  | B  |
| 11:30-13:00   | A | B  | A  |
|---------------+---+----+----|
| Supporting    |   |    |    |
| 13:15-14:45   | B | A  | A  |
| 15:00-16:30   | B | A  | B  |
| 16:45-18:15   | B | B  | B  |
| 20:30-22:00   | B | A  | A  |
|---------------+---+----+----|
|               |   |    |    |
| A:            |   |    |    |
|               |   |    |    |
| B:            |   |    |    |
|               |   |    |    |
| C:            |   |    |    |
|               |   |    |    |
|---------------+---+----+----|
```

## Defining templates

A template maps 9 activity-letter strings to the 9 time slots:

```elisp
(org-weekly-schedule-define-template "my-day" "MD"
  "A" "A" "B"    ; Generative  (04:00, 05:45, 07:30)
  "B" "A"        ; Rewriting   (09:15, 11:30)
  "A" "B"        ; Supporting  (13:15, 15:00)
  "B" "A")       ; Evening     (16:45, 20:30)
```

The first argument is the template name (used at the prompt).  The
second is a short default column header.  The remaining 9 strings are
the slot values from earliest to latest.  Use `""` for any slot you
want to leave blank.

### Built-in templates

| Name             | Header | Description                              |
|------------------|--------|------------------------------------------|
| `research-heavy` | RH     | Deep work all morning on project A       |
| `teaching-day`   | Tch    | Lighter generative, heavier supporting   |
| `balanced`       | Bal    | Alternating A/B throughout the day       |
| `light`          | Lt     | Skips earliest slot, evenings off        |
| `off`            | Off    | Completely blank (rest day placeholder)  |

## Customization

Three `defcustom` variables control the table structure.  Change them
via `M-x customize-group RET org-weekly-schedule RET` or set them in
your init file.

### `org-weekly-schedule-time-slots`

A list of `(TIME-LABEL CATEGORY-OR-NIL)` pairs defining every row in
the Time column.  When `CATEGORY` is non-nil, a separator line and a
category-label row are inserted above that slot.

```elisp
(setq org-weekly-schedule-time-slots
      '(("06:00-07:30" "Morning:")
        ("07:45-09:15" nil)
        ("09:30-11:00" "Midday:")
        ("11:15-12:45" nil)
        ("14:00-15:30" "Afternoon:")
        ("15:45-17:15" nil)))
```

> **Important:** If you change the number of slots, every
> `org-weekly-schedule-define-template` call must supply the matching
> number of values.

### `org-weekly-schedule-legend-keys`

The labels in the legend section at the bottom of the table.

```elisp
(setq org-weekly-schedule-legend-keys '("A:" "B:" "C:" "D:"))
```

### `org-weekly-schedule-day-names`

The day labels used by the interactive week builder.

```elisp
(setq org-weekly-schedule-day-names '("M" "Tu" "W" "Th" "F" "Sa" "Su"))
```

### `org-weekly-schedule-dow-abbreviations`

A 7-element vector of day-of-week abbreviations used by the date
header, indexed 0=Sunday through 6=Saturday.

```elisp
;; Use "Wd" for Wednesday instead of "W":
(setq org-weekly-schedule-dow-abbreviations
      ["Su" "M" "Tu" "Wd" "Th" "F" "Sa"])
```

## Adding a date header

You can add Day and Date rows to the top of any schedule table so that each column shows its calendar date:

```
M-x org-weekly-schedule-add-date-header
Start date for first day column (YYYY-MM-DD): 2026-03-16
```

This produces:

```
|-------------+----+-----+-----+----+----+----+----|
| Day         | M  | Tu  | W   | Th | F  | Sa | Su |
| Date        | 16 | 17  | 18  | 19 | 20 | 21 | 22 |
|-------------+----+-----+-----+----+----+----+----|
| Time        | M  | Tu  | W   | Th | F  | Sa | Su |
|  ...        |    |     |     |    |    |    |    |
```

The week builder also accepts an optional start date.  When called
interactively, it prompts for one before the day-template prompts; when
called from elisp, pass it as the second argument:

```elisp
(org-weekly-schedule-build-week
 '(("M" . "research-heavy") ("Tu" . "balanced"))
 "2026-03-16")
```

## Commands

| Command                                   | Keybinding   | Description                                |
|-------------------------------------------|--------------|--------------------------------------------|
| `org-weekly-schedule-insert`              | `C-c t i`    | Insert bare scaffold at point              |
| `org-weekly-schedule-build-week`          | `C-c t w`    | Insert scaffold + prompt for day templates |
| `org-weekly-schedule-append-column`       | `C-c t a`    | Append an empty column                     |
| `org-weekly-schedule-append-day`          | `C-c t d`    | Append a column from a named template      |
| `org-weekly-schedule-add-date-header`     | `C-c t h`    | Add Day/Date rows to existing table        |
| `org-weekly-schedule-delete-last-column`  | —            | Remove the rightmost column                |

## Running tests

The test suite uses ERT (Emacs Lisp Regression Testing).

```bash
# Run all tests
make test

# Byte-compile
make compile

# Compile with strict warnings (lint)
make lint

# Clean compiled files
make clean

# Compile then test
make all
```

Or run interactively inside Emacs:

```
M-x ert RET t RET
```

## Project structure

```
org-weekly-schedule/
├── Makefile                      # Build and test automation
├── README.md                     # This file
├── org-weekly-schedule.el        # Package source
└── org-weekly-schedule-test.el   # ERT test suite
```

## Status

Still alpha. Works but rough around the edges.


## License

GNU General Public License v3.0 or later.  See the file headers for
the full license text.

## Update table


| Version | Changes                                                                                                                | Date              |
|:---------|:------------------------------------------------------------------------------------------------------------------------|:-------------------|
|   0.1.0   | Initiate project. Added badges, funding, and this update table.                                                        | 2026 March 15 |

## Sources of funding

- NIH: R01 CA242845
- NIH: R01 AI088011
- NIH: P30 CA225520 (PI: R. Mannel)
- NIH: P20 GM103640 and P30 GM145423 (PI: A. West)
