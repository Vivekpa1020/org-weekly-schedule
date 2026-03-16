;;; org-weekly-schedule.el --- Build weekly schedule tables in Org mode -*- lexical-binding: t; -*-

;; Author: Blaine Mooers <blaine-mooers@ouhsc.edu>
;; Maintainer: Blaine Mooers <blaine-mooers@ouhsc.edu>
;; Version: 0.1.0
;; Package-Requires: ((emacs "25.1") (org "9.0"))
;; Keywords: calendar, convenience, org
;; URL: https://github.com/MooersLab/org-weekly-schedule

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; org-weekly-schedule builds weekly time-block schedule tables inside
;; Org mode buffers.  It works in three layers:
;;
;; 1. SCAFFOLD — `org-weekly-schedule-insert' generates a base table
;;    containing just the left-hand Time column: time-slot labels
;;    grouped under category headings (Generative, Rewriting,
;;    Supporting) with a legend section at the bottom.  Think of it
;;    as the ruled lines pre-printed on every page of a weekly
;;    planner.
;;
;; 2. COLUMN STAMPING — `org-weekly-schedule-append-day' appends a
;;    single day column using a named template.  Each template maps
;;    activity letters (A, B, etc.) to the nine time slots.  You can
;;    call this repeatedly to build a week incrementally.
;;
;; 3. WEEK BUILDER — `org-weekly-schedule-build-week' combines both
;;    steps: it inserts the scaffold and then stamps day columns for
;;    Monday through Saturday in one interactive command.
;;
;; Templates are defined with `org-weekly-schedule-define-template'.
;; You supply 9 slot values (one per time block) and the function
;; expands them into the full 20-row layout automatically, inserting
;; empty strings for category-label rows and legend rows.
;;
;; The time grid is stored in `org-weekly-schedule-time-slots' and the
;; legend keys in `org-weekly-schedule-legend-keys'.  Changing these
;; variables reshapes every table the package generates.

;;; Usage:
;;
;;   (require 'org-weekly-schedule)
;;
;;   ;; Insert a blank scaffold at point:
;;   M-x org-weekly-schedule-insert
;;
;;   ;; Build an entire week interactively (prompts for each day):
;;   M-x org-weekly-schedule-build-week
;;
;;   ;; Append one day column from a template:
;;   M-x org-weekly-schedule-append-day
;;
;;   ;; Append an empty column (fill in manually):
;;   M-x org-weekly-schedule-append-column
;;
;;   ;; Add Day/Date header rows to an existing table:
;;   M-x org-weekly-schedule-add-date-header
;;
;;   Suggested keybindings:
;;
;;     (with-eval-after-load 'org
;;       (define-key org-mode-map (kbd "C-c t i") #'org-weekly-schedule-insert)
;;       (define-key org-mode-map (kbd "C-c t w") #'org-weekly-schedule-build-week)
;;       (define-key org-mode-map (kbd "C-c t a") #'org-weekly-schedule-append-column)
;;       (define-key org-mode-map (kbd "C-c t d") #'org-weekly-schedule-append-day)
;;       (define-key org-mode-map (kbd "C-c t h") #'org-weekly-schedule-add-date-header))

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-table)


;;; ======================================================================
;;; Custom group
;;; ======================================================================

(defgroup org-weekly-schedule nil
  "Build weekly time-block schedule tables in Org mode."
  :group 'org
  :prefix "org-weekly-schedule-")


;;; ======================================================================
;;; User-configurable variables
;;; ======================================================================

(defcustom org-weekly-schedule-time-slots
  '(("04:00-05:30"   "Generative:")
    ("05:45-07:15"   nil)
    ("07:30-09:00"   nil)
    ("09:15-10:45"   "Rewriting:")
    ("11:30-13:00"   nil)
    ("13:15-14:45"   "Supporting")
    ("15:00-16:30"   nil)
    ("16:45-18:15"   nil)
    ("20:30-22:00"   nil))
  "Time-slot definitions for the schedule table.

Each element is a list of the form (TIME-LABEL CATEGORY-OR-NIL).
TIME-LABEL is the string shown in the leftmost column (e.g.
\"04:00-05:30\").  CATEGORY-OR-NIL, when non-nil, causes a
horizontal separator and a category-label row to be emitted
immediately above that time slot.

The order of entries determines row order in the generated table.
Modifying this variable changes the scaffold globally; you must
also update `org-weekly-schedule-define-template' calls to match
the new slot count."
  :type '(repeat (list string (choice (const nil) string)))
  :group 'org-weekly-schedule)

(defcustom org-weekly-schedule-legend-keys '("A:" "B:" "C:")
  "Legend labels shown at the bottom of the schedule table.

Each entry becomes a labeled row with blank spacer rows above
and below it.  Use these to document what each activity letter
represents for a given week."
  :type '(repeat string)
  :group 'org-weekly-schedule)

(defcustom org-weekly-schedule-day-names '("M" "Tu" "W" "Th" "F" "Sa")
  "Day-name headers used by `org-weekly-schedule-build-week'.

Each string becomes the column header when the week builder
prompts interactively.  Modify this list to change the number
or names of days (e.g. add \"Su\" for a seven-day schedule)."
  :type '(repeat string)
  :group 'org-weekly-schedule)

(defcustom org-weekly-schedule-dow-abbreviations
  ["Su" "M" "Tu" "W" "Th" "F" "Sa"]
  "Day-of-week abbreviations indexed by `format-time-string' %w.

Index 0 = Sunday, 1 = Monday, ..., 6 = Saturday.  These are the
strings placed in the Day header row by
`org-weekly-schedule-add-date-header'.  Modify this vector to
change the abbreviations (e.g. use \"Wd\" instead of \"W\" for
Wednesday)."
  :type '(vector string string string string string string string)
  :group 'org-weekly-schedule)


;;; ======================================================================
;;; Template registry
;;; ======================================================================

(defvar org-weekly-schedule-templates nil
  "Alist of (NAME . VALUES) day-schedule templates.

Each VALUES list contains one string per data row in the schedule
table (20 rows for the default time-slot configuration).
Separator rows are handled automatically and are not represented
here.

Do not edit this variable directly.  Use
`org-weekly-schedule-define-template' to register templates.")


;;; ======================================================================
;;; Internal helpers
;;; ======================================================================

(defun org-weekly-schedule--slot-count ()
  "Return the number of time slots in the current configuration."
  (length org-weekly-schedule-time-slots))

(defun org-weekly-schedule--column-count ()
  "Return the number of columns in the Org table at point.

This is a portable alternative to `org-table-current-ncol',
which is unavailable in some Org versions.  It counts the pipe
delimiters on the first data row (skipping separator rows) and
returns one fewer than the pipe count."
  (save-excursion
    (goto-char (org-table-begin))
    ;; Skip separator rows to reach a data row
    (while (and (< (point) (org-table-end))
                (looking-at "\\s-*|[-+]"))
      (forward-line 1))
    (let ((line (buffer-substring-no-properties
                 (line-beginning-position) (line-end-position)))
          (count 0)
          (start 0))
      (while (string-match "|" line start)
        (cl-incf count)
        (setq start (match-end 0)))
      (max 0 (1- count)))))

(defun org-weekly-schedule--data-row-count ()
  "Return the expected number of data rows in a complete table.

This accounts for:
  - 1 header row
  - 1 category-label row per slot that has a non-nil category
  - 1 row per time slot
  - 1 spacer + 1 label row per legend key, plus 1 trailing spacer."
  (let ((header-rows 1)
        (category-rows (cl-count-if (lambda (s) (cadr s))
                                    org-weekly-schedule-time-slots))
        (slot-rows (org-weekly-schedule--slot-count))
        (legend-rows (+ (* 2 (length org-weekly-schedule-legend-keys)) 1)))
    (+ header-rows category-rows slot-rows legend-rows)))

(defun org-weekly-schedule--base-table-string ()
  "Return the base schedule table as a string with no day columns.

The table has a single column (Time) containing the header,
category labels, time-slot labels, and legend rows.  Separator
rows (|---...|) divide categories.  The string does NOT include
a trailing newline."
  (let ((sep   "|---------|")
        (lines '()))
    ;; Header
    (push sep lines)
    (push "| Time    |" lines)
    ;; Time-slot rows, grouped by category
    (dolist (slot org-weekly-schedule-time-slots)
      (let ((time-label (car slot))
            (category   (cadr slot)))
        (when category
          (push sep lines)
          (push (format "| %-7s |" category) lines))
        (push (format "| %-7s |" time-label) lines)))
    ;; Separator before legend
    (push sep lines)
    ;; Legend section: spacer, key, spacer, key, ... spacer
    (dolist (key org-weekly-schedule-legend-keys)
      (push "|         |" lines)
      (push (format "| %-7s |" key) lines))
    (push "|         |" lines)
    ;; Bottom border
    (push sep lines)
    (mapconcat #'identity (nreverse lines) "\n")))

(defun org-weekly-schedule--expand-slots (header slot-values)
  "Expand HEADER and SLOT-VALUES into a full 20-row value list.

HEADER is the column-header string.  SLOT-VALUES is a list of
strings, one per time slot (length must equal the slot count).

The returned list has one entry per data row in the schedule
table.  Category-label rows and legend rows are filled with
empty strings."
  (let* ((expected (org-weekly-schedule--slot-count))
         (values (list header))
         (sv-idx 0))
    (unless (= (length slot-values) expected)
      (error "Expected %d slot values, got %d"
             expected (length slot-values)))
    ;; Walk the time-slot definitions to build the row list
    (dolist (slot org-weekly-schedule-time-slots)
      (when (cadr slot)                 ; category label row
        (push "" values))
      (push (nth sv-idx slot-values) values)
      (cl-incf sv-idx))
    ;; Legend section
    (dolist (_key org-weekly-schedule-legend-keys)
      (push "" values)                  ; spacer
      (push "" values))                 ; label row
    (push "" values)                    ; trailing spacer
    (nreverse values)))


;;; ======================================================================
;;; Core: append a column to any Org table
;;; ======================================================================

(defun org-weekly-schedule-append-column (&optional values)
  "Append a column to the right side of the Org table at point.

VALUES is an optional list of strings, one per data row from top
to bottom.  Separator rows (lines matching |[-+]...|) receive
separator markup automatically and do NOT consume a value.

When VALUES is nil or shorter than the number of data rows, the
remaining cells are left empty.

The table is realigned with `org-table-align' after insertion."
  (interactive)
  (unless (org-at-table-p)
    (user-error "Point is not inside an Org table"))
  (let ((beg     (org-table-begin))
        (end-mk  (copy-marker (org-table-end)))
        (val-idx 0))
    (save-excursion
      (goto-char beg)
      (while (< (point) end-mk)
        (let ((bol (line-beginning-position)))
          (end-of-line)
          (skip-chars-backward " \t")
          ;; Only process lines belonging to the table (ending with |)
          (when (eq (char-before) ?|)
            (if (save-excursion
                  (goto-char bol)
                  (looking-at "\\s-*|[-+]"))
                ;; Separator row: splice +---- before the closing |
                (progn
                  (backward-char 1)
                  (insert "+----"))
              ;; Data row: append a new cell after the closing |
              (let ((val (if (and values (< val-idx (length values)))
                             (or (nth val-idx values) "")
                           "")))
                (insert (format " %s |" val))
                (cl-incf val-idx)))))
        (forward-line 1))
      ;; Realign the table so column widths are uniform
      (goto-char beg)
      (org-table-align)
      (set-marker end-mk nil)
      (message "Column appended."))))


;;; ======================================================================
;;; Scaffold: insert the base table
;;; ======================================================================

(defun org-weekly-schedule-insert ()
  "Insert a bare schedule table at point.

The table contains only the Time column (left-hand labels).
Use `org-weekly-schedule-append-day' or
`org-weekly-schedule-append-column' to add day columns."
  (interactive)
  (insert (org-weekly-schedule--base-table-string))
  (insert "\n")
  ;; Move point inside the table so Org recognises it, then align.
  (forward-line -2)
  (org-table-align)
  (message "Base schedule table inserted."))


;;; ======================================================================
;;; Template system
;;; ======================================================================

(defun org-weekly-schedule-define-template (name header &rest slot-values)
  "Define or redefine a day-schedule template called NAME.

HEADER is the default column-header string (e.g. \"RH\" or
\"Tch\").  It is overridden by the actual day name when the
template is stamped via `org-weekly-schedule-build-week'.

SLOT-VALUES are activity-letter strings for the time slots, in
order from earliest to latest.  The number of values must match
the number of entries in `org-weekly-schedule-time-slots' (9 by
default):

  Slot 0: 04:00-05:30  \\=┐
  Slot 1: 05:45-07:15  \\=├─ Generative  (3 slots)
  Slot 2: 07:30-09:00  \\=┘
  Slot 3: 09:15-10:45  \\=┐
  Slot 4: 11:30-13:00  \\=┘─ Rewriting   (2 slots)
  Slot 5: 13:15-14:45  \\=┐
  Slot 6: 15:00-16:30  \\=┘─ Supporting  (2 slots)
  Slot 7: 16:45-18:15  \\=┐
  Slot 8: 20:30-22:00  \\=┘─ Evening     (2 slots)

Use an empty string \"\" for any slot you want left blank."
  (let ((values (org-weekly-schedule--expand-slots header slot-values)))
    (setf (alist-get name org-weekly-schedule-templates
                     nil nil #'string=)
          values)
    (message "Template '%s' defined." name)))


;;; ======================================================================
;;; Built-in example templates
;;; ======================================================================

;; "research-heavy": deep-work day — generative and rewriting on A
(org-weekly-schedule-define-template "research-heavy" "RH"
  "A" "A" "A"    ; Generative: project A all morning
  "A" "A"        ; Rewriting:  project A
  "B" "B"        ; Supporting: project B
  "B" "B")       ; Evening:    project B

;; "teaching-day": lighter generative, heavier supporting
(org-weekly-schedule-define-template "teaching-day" "Tch"
  "B" "B" "A"    ; Generative
  "A" "B"        ; Rewriting
  "A" "A"        ; Supporting
  "B" "A")       ; Evening

;; "balanced": alternating A/B throughout the day
(org-weekly-schedule-define-template "balanced" "Bal"
  "A" "B" "A"    ; Generative
  "B" "A"        ; Rewriting
  "A" "B"        ; Supporting
  "B" "A")       ; Evening

;; "light": skip the earliest slot, evenings off
(org-weekly-schedule-define-template "light" "Lt"
  ""  "B" "B"    ; Generative (04:00 slot blank)
  "A" "A"        ; Rewriting
  "A" "A"        ; Supporting
  ""  "")        ; Evening off

;; "off": completely blank column (rest day placeholder)
(org-weekly-schedule-define-template "off" "Off"
  ""  ""  ""
  ""  ""
  ""  ""
  ""  "")


;;; ======================================================================
;;; Interactive: stamp a template as a day column
;;; ======================================================================

(defun org-weekly-schedule-append-day (name)
  "Append a day column to the schedule table using template NAME.

Prompts with minibuffer completion from the registered templates
in `org-weekly-schedule-templates'."
  (interactive
   (list (completing-read "Day template: "
                          (mapcar #'car org-weekly-schedule-templates)
                          nil t)))
  (let ((values (alist-get name org-weekly-schedule-templates
                           nil nil #'string=)))
    (unless values
      (user-error "No template named '%s'" name))
    (org-weekly-schedule-append-column values)))


;;; ======================================================================
;;; Week builder: scaffold + stamp all day columns at once
;;; ======================================================================

(defun org-weekly-schedule-build-week (day-specs &optional start-date)
  "Insert a complete weekly schedule table at point.

DAY-SPECS is a list of (HEADER . TEMPLATE-NAME) cons cells, one
per day column to create.  For example:

  \\='((\"M\"  . \"research-heavy\")
    (\"Tu\" . \"teaching-day\")
    (\"W\"  . \"balanced\"))

Optional START-DATE is a YYYY-MM-DD string for the first day
column.  When provided, Day and Date header rows are added at the
top of the table.  When nil, no date header is added.

When called interactively, the command prompts for each day in
`org-weekly-schedule-day-names' using minibuffer completion over
the registered template names.  Press RET on an empty input to
skip that day.  The command also prompts for a start date; press
RET to omit the date header."
  (interactive
   (let* ((template-names (mapcar #'car org-weekly-schedule-templates))
          (specs '())
          (date-input (read-string
                       "Start date (YYYY-MM-DD, RET to skip): ")))
     (dolist (day org-weekly-schedule-day-names)
       (let ((tmpl (completing-read
                    (format "Template for %s (RET to skip): " day)
                    template-names nil nil)))
         (unless (string-empty-p tmpl)
           (push (cons day tmpl) specs))))
     (list (nreverse specs)
           (if (string-empty-p date-input) nil date-input))))
  ;; 1. Insert the bare scaffold
  (let ((start (point)))
    (org-weekly-schedule-insert)
    ;; 2. Stamp each day column onto the scaffold
    (goto-char start)
    (forward-line 1)                    ; move into the table body
    (dolist (spec day-specs)
      (let* ((header     (car spec))
             (tmpl-name  (cdr spec))
             (tmpl-values (alist-get tmpl-name
                                     org-weekly-schedule-templates
                                     nil nil #'string=)))
        (unless tmpl-values
          (user-error "Unknown template '%s'" tmpl-name))
        ;; Override the stored header with the actual day name
        (let ((values (cons header (cdr tmpl-values))))
          (org-weekly-schedule-append-column values))))
    ;; 3. Optionally add Day/Date header rows
    (when start-date
      (goto-char start)
      (forward-line 1)
      (org-weekly-schedule-add-date-header start-date))
    (message "Week schedule built with %d day(s)." (length day-specs))))


;;; ======================================================================
;;; Date header: Day and Date rows at the top of the table
;;; ======================================================================

(defun org-weekly-schedule--parse-date (date-string)
  "Parse DATE-STRING (YYYY-MM-DD) into an Emacs time value.
Signals `user-error' if the format is invalid."
  (unless (string-match
           "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)\\'"
           date-string)
    (user-error "Date must be YYYY-MM-DD, got '%s'" date-string))
  (let ((year  (string-to-number (match-string 1 date-string)))
        (month (string-to-number (match-string 2 date-string)))
        (day   (string-to-number (match-string 3 date-string))))
    (encode-time 0 0 12 day month year)))

(defun org-weekly-schedule-add-date-header (start-date)
  "Add Day and Date header rows to the schedule table at point.

START-DATE is a string in YYYY-MM-DD format giving the calendar
date for the first day column (the column immediately after the
Time column).  Consecutive dates are generated for every
remaining day column.

Two new rows are inserted between the top separator and the
existing Time header:

  | Day  | M  | Tu | W  | Th | F  | Sa |
  | Date | 16 | 17 | 18 | 19 | 20 | 21 |

Day abbreviations come from `org-weekly-schedule-dow-abbreviations'.
The table is realigned after insertion."
  (interactive "sStart date for first day column (YYYY-MM-DD): ")
  (unless (org-at-table-p)
    (user-error "Point is not inside an Org table"))
  (let* ((ncols   (org-weekly-schedule--column-count))
         (ndays   (1- ncols))           ; first column is Time/labels
         (base    (org-weekly-schedule--parse-date start-date))
         (day-abbrevs '())
         (date-nums   '()))
    (when (<= ndays 0)
      (user-error "Table has no day columns to label"))
    ;; Compute abbreviations and date numbers for each day column
    (dotimes (i ndays)
      (let ((day-time (time-add base (days-to-time i))))
        (push (aref org-weekly-schedule-dow-abbreviations
                    (string-to-number (format-time-string "%w" day-time)))
              day-abbrevs)
        (push (format-time-string "%-d" day-time) date-nums)))
    (setq day-abbrevs (nreverse day-abbrevs))
    (setq date-nums   (nreverse date-nums))
    ;; Build the two row strings
    (let ((day-row  (concat "| Day "
                            (mapconcat (lambda (d) (format "| %s " d))
                                       day-abbrevs "")
                            "|\n"))
          (date-row (concat "| Date "
                            (mapconcat (lambda (d) (format "| %s " d))
                                       date-nums "")
                            "|\n")))
      (save-excursion
        (goto-char (org-table-begin))
        ;; Move past the first separator row
        (forward-line 1)
        ;; Insert Day and Date rows before the Time header row
        (insert day-row)
        (insert date-row)
        ;; Realign
        (goto-char (org-table-begin))
        (org-table-align)
        (message "Day/Date header added for %d day(s)." ndays)))))


;;; ======================================================================
;;; Convenience: remove the rightmost column
;;; ======================================================================

(defun org-weekly-schedule-delete-last-column ()
  "Delete the rightmost column of the Org table at point.
Useful for undoing an accidental column append."
  (interactive)
  (unless (org-at-table-p)
    (user-error "Point is not inside an Org table"))
  (save-excursion
    (org-table-goto-column (org-weekly-schedule--column-count))
    (org-table-delete-column)))


;;; ======================================================================
;;; Provide
;;; ======================================================================

(provide 'org-weekly-schedule)
;;; org-weekly-schedule.el ends here
