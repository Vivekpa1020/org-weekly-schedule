;;; org-weekly-schedule-test.el --- ERT tests for org-weekly-schedule -*- lexical-binding: t; -*-

;; Author: Blaine Mooers <blaine-mooers@ouhsc.edu>

;;; Commentary:

;; Comprehensive test suite for org-weekly-schedule.el.
;;
;; Run interactively:   M-x ert RET t RET
;; Run from the shell:  make test
;;                  or:  emacs -Q --batch -L . -l org-weekly-schedule-test.el \
;;                           -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'org)
(require 'org-table)
(require 'org-weekly-schedule)


;;; ======================================================================
;;; Test helpers
;;; ======================================================================

(defmacro ows-test-with-org-buffer (&rest body)
  "Execute BODY in a temporary Org mode buffer.
The buffer is set to `org-mode' so that table functions work."
  (declare (indent 0) (debug t))
  `(with-temp-buffer
     (org-mode)
     ,@body))

(defun ows-test-insert-minimal-table ()
  "Insert a small 2x2 Org table for low-level append tests.
Returns point at the beginning of the table."
  (let ((start (point)))
    (insert "|---+---|\n")
    (insert "| A | 1 |\n")
    (insert "| B | 2 |\n")
    (insert "|---+---|\n")
    (goto-char start)
    (forward-line 1)                    ; land inside the table
    start))

(defun ows-test-table-string ()
  "Return the full text of the Org table at point as a string."
  (buffer-substring-no-properties
   (org-table-begin) (org-table-end)))

(defun ows-test-count-columns ()
  "Return the number of columns in the Org table at point.
Uses the portable pipe-counting helper from the package."
  (org-weekly-schedule--column-count))

(defun ows-test-count-separator-rows ()
  "Count separator rows (|---...|) in the Org table at point."
  (let ((count 0)
        (beg (org-table-begin))
        (end (org-table-end)))
    (save-excursion
      (goto-char beg)
      (while (< (point) end)
        (when (looking-at "\\s-*|[-+]")
          (cl-incf count))
        (forward-line 1)))
    count))

(defun ows-test-count-data-rows ()
  "Count data rows (non-separator) in the Org table at point."
  (let ((count 0)
        (beg (org-table-begin))
        (end (org-table-end)))
    (save-excursion
      (goto-char beg)
      (while (< (point) end)
        (when (and (looking-at "\\s-*|")
                   (not (looking-at "\\s-*|[-+]")))
          (cl-incf count))
        (forward-line 1)))
    count))

(defun ows-test-cell-value (row col)
  "Return the trimmed string in ROW, COL of the Org table at point.
ROW and COL are 1-based.  Skips separator rows when counting."
  (save-excursion
    (goto-char (org-table-begin))
    (let ((data-row 0))
      (while (< data-row row)
        (if (looking-at "\\s-*|[-+]")
            nil                         ; skip separators
          (cl-incf data-row))
        (when (< data-row row)
          (forward-line 1)))
      ;; Now on the correct data row
      (org-table-goto-column col)
      (string-trim (org-table-get-field col)))))


;;; ======================================================================
;;; Tests: internal helpers
;;; ======================================================================

(ert-deftest ows-test-slot-count ()
  "Verify slot count matches the default configuration."
  (should (= (org-weekly-schedule--slot-count) 9)))

(ert-deftest ows-test-data-row-count ()
  "Verify expected data-row count for the default configuration.
With 9 slots, 3 category labels, 3 legend keys: 1 + 3 + 9 + 7 = 20."
  (should (= (org-weekly-schedule--data-row-count) 20)))

(ert-deftest ows-test-expand-slots-length ()
  "Expanding 9 slot values should produce exactly 20 data-row values."
  (let ((values (org-weekly-schedule--expand-slots
                 "X" '("a" "b" "c" "d" "e" "f" "g" "h" "i"))))
    (should (= (length values) 20))))

(ert-deftest ows-test-expand-slots-header ()
  "The first element of expanded values should be the header."
  (let ((values (org-weekly-schedule--expand-slots
                 "Day1" '("a" "b" "c" "d" "e" "f" "g" "h" "i"))))
    (should (string= (car values) "Day1"))))

(ert-deftest ows-test-expand-slots-values-placement ()
  "Slot values should land in the correct data-row positions.
Row 0 = header, row 1 = Generative label (empty), rows 2-4 = slots 0-2."
  (let ((values (org-weekly-schedule--expand-slots
                 "Hdr" '("s0" "s1" "s2" "s3" "s4" "s5" "s6" "s7" "s8"))))
    ;; Row 1 is the Generative label — should be empty
    (should (string= (nth 1 values) ""))
    ;; Rows 2, 3, 4 are the three Generative time slots
    (should (string= (nth 2 values) "s0"))
    (should (string= (nth 3 values) "s1"))
    (should (string= (nth 4 values) "s2"))
    ;; Row 5 is the Rewriting label — should be empty
    (should (string= (nth 5 values) ""))
    ;; Rows 6, 7 are the two Rewriting slots
    (should (string= (nth 6 values) "s3"))
    (should (string= (nth 7 values) "s4"))
    ;; Row 8 is the Supporting label — should be empty
    (should (string= (nth 8 values) ""))
    ;; Rows 9, 10 are the two Supporting slots
    (should (string= (nth 9 values) "s5"))
    (should (string= (nth 10 values) "s6"))
    ;; Rows 11, 12 are the two Evening slots
    (should (string= (nth 11 values) "s7"))
    (should (string= (nth 12 values) "s8"))))

(ert-deftest ows-test-expand-slots-wrong-count ()
  "Passing the wrong number of slot values should signal an error."
  (should-error
   (org-weekly-schedule--expand-slots "X" '("a" "b" "c"))
   :type 'error))


;;; ======================================================================
;;; Tests: base table string
;;; ======================================================================

(ert-deftest ows-test-base-table-string-not-empty ()
  "The base table string should be non-empty."
  (should (> (length (org-weekly-schedule--base-table-string)) 0)))

(ert-deftest ows-test-base-table-string-starts-with-separator ()
  "The base table string should start with a separator row."
  (should (string-prefix-p "|---" (org-weekly-schedule--base-table-string))))

(ert-deftest ows-test-base-table-string-ends-with-separator ()
  "The base table string should end with a separator row."
  (should (string-suffix-p "----|"
                           (string-trim-right
                            (org-weekly-schedule--base-table-string)))))

(ert-deftest ows-test-base-table-contains-header ()
  "The base table should contain a Time header row."
  (should (string-match-p "| Time" (org-weekly-schedule--base-table-string))))

(ert-deftest ows-test-base-table-contains-categories ()
  "The base table should contain all three category labels."
  (let ((tbl (org-weekly-schedule--base-table-string)))
    (should (string-match-p "Generative" tbl))
    (should (string-match-p "Rewriting" tbl))
    (should (string-match-p "Supporting" tbl))))

(ert-deftest ows-test-base-table-contains-legend ()
  "The base table should contain all legend keys."
  (let ((tbl (org-weekly-schedule--base-table-string)))
    (dolist (key org-weekly-schedule-legend-keys)
      (should (string-match-p (regexp-quote key) tbl)))))


;;; ======================================================================
;;; Tests: scaffold insertion
;;; ======================================================================

(ert-deftest ows-test-insert-creates-valid-org-table ()
  "Inserting the scaffold should produce a valid Org table."
  (ows-test-with-org-buffer
    (org-weekly-schedule-insert)
    ;; Point should be inside the table
    (should (org-at-table-p))))

(ert-deftest ows-test-insert-single-column ()
  "The scaffold table should have exactly one column."
  (ows-test-with-org-buffer
    (org-weekly-schedule-insert)
    (should (= (ows-test-count-columns) 1))))

(ert-deftest ows-test-insert-data-row-count ()
  "The scaffold should have the expected number of data rows."
  (ows-test-with-org-buffer
    (org-weekly-schedule-insert)
    (should (= (ows-test-count-data-rows) 20))))

(ert-deftest ows-test-insert-separator-count ()
  "The scaffold should have 6 separator rows.
Top, after header, after Generative, after Rewriting, after Supporting,
bottom."
  (ows-test-with-org-buffer
    (org-weekly-schedule-insert)
    (should (= (ows-test-count-separator-rows) 6))))


;;; ======================================================================
;;; Tests: append column (generic, low-level)
;;; ======================================================================

(ert-deftest ows-test-append-column-adds-column ()
  "Appending a column to a 2-column table should yield 3 columns."
  (ows-test-with-org-buffer
    (ows-test-insert-minimal-table)
    (org-weekly-schedule-append-column)
    (should (= (ows-test-count-columns) 3))))

(ert-deftest ows-test-append-column-with-values ()
  "Appending with values should place them in the correct cells."
  (ows-test-with-org-buffer
    (ows-test-insert-minimal-table)
    (org-weekly-schedule-append-column '("X" "Y"))
    (should (string= (ows-test-cell-value 1 3) "X"))
    (should (string= (ows-test-cell-value 2 3) "Y"))))

(ert-deftest ows-test-append-column-separator-integrity ()
  "Separator rows should gain +-- segments, not data cells.
After `org-table-align', the dash count may differ from the
initial +---- that was inserted, because alignment normalises
column widths.  We check for at least +-- (one plus followed by
two or more dashes)."
  (ows-test-with-org-buffer
    (ows-test-insert-minimal-table)
    (org-weekly-schedule-append-column)
    (let ((tbl (ows-test-table-string)))
      ;; Every separator line should have at least two +--- segments
      ;; (one from the original table, one from the appended column)
      (dolist (line (split-string tbl "\n" t))
        (when (string-match-p "^\\s-*|[-+]" line)
          ;; Count the number of + characters (column boundaries)
          ;; A 3-column table has 2 internal boundaries = 2 plus signs
          (let ((plus-count 0) (pos 0))
            (while (string-match "\\+" line pos)
              (cl-incf plus-count)
              (setq pos (match-end 0)))
            (should (>= plus-count 2))))))))

(ert-deftest ows-test-append-column-preserves-existing-data ()
  "Existing cell values should be unchanged after appending a column."
  (ows-test-with-org-buffer
    (ows-test-insert-minimal-table)
    (org-weekly-schedule-append-column '("X" "Y"))
    ;; Original columns should still have their values
    (should (string= (ows-test-cell-value 1 1) "A"))
    (should (string= (ows-test-cell-value 1 2) "1"))
    (should (string= (ows-test-cell-value 2 1) "B"))
    (should (string= (ows-test-cell-value 2 2) "2"))))

(ert-deftest ows-test-append-column-short-values ()
  "When fewer values than data rows are given, extras should be empty."
  (ows-test-with-org-buffer
    (ows-test-insert-minimal-table)
    ;; Only one value for a 2-data-row table
    (org-weekly-schedule-append-column '("X"))
    (should (string= (ows-test-cell-value 1 3) "X"))
    (should (string= (ows-test-cell-value 2 3) ""))))

(ert-deftest ows-test-append-column-twice ()
  "Appending two columns should yield the correct total."
  (ows-test-with-org-buffer
    (ows-test-insert-minimal-table)
    (org-weekly-schedule-append-column '("X" "Y"))
    (org-weekly-schedule-append-column '("P" "Q"))
    (should (= (ows-test-count-columns) 4))
    (should (string= (ows-test-cell-value 1 4) "P"))
    (should (string= (ows-test-cell-value 2 4) "Q"))))

(ert-deftest ows-test-append-column-not-in-table ()
  "Calling append-column outside a table should signal user-error."
  (ows-test-with-org-buffer
    (insert "Just some text, not a table.\n")
    (should-error (org-weekly-schedule-append-column)
                  :type 'user-error)))


;;; ======================================================================
;;; Tests: append column on the schedule scaffold
;;; ======================================================================

(ert-deftest ows-test-append-to-scaffold-adds-column ()
  "Appending an empty column to the scaffold should give 2 columns."
  (ows-test-with-org-buffer
    (org-weekly-schedule-insert)
    (org-weekly-schedule-append-column)
    (should (= (ows-test-count-columns) 2))))

(ert-deftest ows-test-append-to-scaffold-preserves-row-counts ()
  "Data and separator row counts should be unchanged after appending."
  (ows-test-with-org-buffer
    (org-weekly-schedule-insert)
    (let ((data-before (ows-test-count-data-rows))
          (sep-before  (ows-test-count-separator-rows)))
      (org-weekly-schedule-append-column)
      (should (= (ows-test-count-data-rows) data-before))
      (should (= (ows-test-count-separator-rows) sep-before)))))


;;; ======================================================================
;;; Tests: template system
;;; ======================================================================

(ert-deftest ows-test-define-template-registers ()
  "Defining a template should add it to the templates alist."
  (let ((org-weekly-schedule-templates nil))
    (org-weekly-schedule-define-template "test-tmpl" "T"
      "a" "b" "c" "d" "e" "f" "g" "h" "i")
    (should (assoc "test-tmpl" org-weekly-schedule-templates))))

(ert-deftest ows-test-define-template-value-count ()
  "A defined template should have exactly 20 values."
  (let ((org-weekly-schedule-templates nil))
    (org-weekly-schedule-define-template "test-tmpl" "T"
      "a" "b" "c" "d" "e" "f" "g" "h" "i")
    (should (= (length (cdr (assoc "test-tmpl"
                                   org-weekly-schedule-templates)))
               20))))

(ert-deftest ows-test-define-template-redefine ()
  "Redefining a template should update rather than duplicate it."
  (let ((org-weekly-schedule-templates nil))
    (org-weekly-schedule-define-template "dup" "V1"
      "a" "b" "c" "d" "e" "f" "g" "h" "i")
    (org-weekly-schedule-define-template "dup" "V2"
      "x" "y" "z" "d" "e" "f" "g" "h" "i")
    ;; Should have exactly one entry for "dup"
    (should (= (cl-count "dup" org-weekly-schedule-templates
                         :key #'car :test #'string=)
               1))
    ;; Header should be the updated value
    (let ((vals (alist-get "dup" org-weekly-schedule-templates
                           nil nil #'string=)))
      (should (string= (car vals) "V2")))))

(ert-deftest ows-test-define-template-wrong-slot-count ()
  "Defining a template with the wrong number of slots should error."
  (let ((org-weekly-schedule-templates nil))
    (should-error
     (org-weekly-schedule-define-template "bad" "B" "a" "b")
     :type 'error)))

(ert-deftest ows-test-builtin-templates-exist ()
  "All five built-in templates should be registered."
  (dolist (name '("research-heavy" "teaching-day" "balanced" "light" "off"))
    (should (assoc name org-weekly-schedule-templates))))


;;; ======================================================================
;;; Tests: append-day (template stamping)
;;; ======================================================================

(ert-deftest ows-test-append-day-adds-column ()
  "Stamping a template onto the scaffold should add one column."
  (ows-test-with-org-buffer
    (org-weekly-schedule-insert)
    (org-weekly-schedule-append-day "research-heavy")
    (should (= (ows-test-count-columns) 2))))

(ert-deftest ows-test-append-day-header-value ()
  "The stamped column header should match the template default header."
  (ows-test-with-org-buffer
    (org-weekly-schedule-insert)
    (org-weekly-schedule-append-day "research-heavy")
    ;; Data row 1 is the header row, column 2 is the new column
    (should (string= (ows-test-cell-value 1 2) "RH"))))

(ert-deftest ows-test-append-day-slot-values ()
  "Slot values from the research-heavy template should be correct."
  (ows-test-with-org-buffer
    (org-weekly-schedule-insert)
    (org-weekly-schedule-append-day "research-heavy")
    ;; Data row 3 = first time slot (04:00-05:30), column 2
    (should (string= (ows-test-cell-value 3 2) "A"))
    ;; Data row 10 = first Supporting slot (13:15-14:45)
    (should (string= (ows-test-cell-value 10 2) "B"))))

(ert-deftest ows-test-append-day-unknown-template ()
  "Appending with a nonexistent template name should signal user-error."
  (ows-test-with-org-buffer
    (org-weekly-schedule-insert)
    (should-error (org-weekly-schedule-append-day "no-such-template")
                  :type 'user-error)))

(ert-deftest ows-test-append-multiple-days ()
  "Stamping three templates should produce 4 columns total."
  (ows-test-with-org-buffer
    (org-weekly-schedule-insert)
    (org-weekly-schedule-append-day "research-heavy")
    (org-weekly-schedule-append-day "balanced")
    (org-weekly-schedule-append-day "off")
    (should (= (ows-test-count-columns) 4))))


;;; ======================================================================
;;; Tests: week builder
;;; ======================================================================

(ert-deftest ows-test-build-week-basic ()
  "Building a 3-day week should produce a 4-column table."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("M" . "research-heavy")
       ("Tu" . "teaching-day")
       ("W" . "balanced")))
    (should (org-at-table-p))
    (should (= (ows-test-count-columns) 4))))

(ert-deftest ows-test-build-week-full ()
  "Building a full 6-day week should produce a 7-column table."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("M"  . "research-heavy")
       ("Tu" . "teaching-day")
       ("W"  . "balanced")
       ("Th" . "research-heavy")
       ("F"  . "light")
       ("Sa" . "off")))
    (should (= (ows-test-count-columns) 7))))

(ert-deftest ows-test-build-week-header-override ()
  "Day names from the spec should override template default headers."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("M" . "research-heavy")))
    ;; The header should be "M", not the template default "RH"
    (should (string= (ows-test-cell-value 1 2) "M"))))

(ert-deftest ows-test-build-week-empty-specs ()
  "Building with no day specs should insert the scaffold only."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week '())
    (should (org-at-table-p))
    (should (= (ows-test-count-columns) 1))))

(ert-deftest ows-test-build-week-unknown-template ()
  "Building with an unknown template should signal user-error."
  (ows-test-with-org-buffer
    (should-error
     (org-weekly-schedule-build-week '(("M" . "nonexistent")))
     :type 'user-error)))


;;; ======================================================================
;;; Tests: delete last column
;;; ======================================================================

(ert-deftest ows-test-delete-last-column ()
  "Deleting the last column should reduce column count by one."
  (ows-test-with-org-buffer
    (ows-test-insert-minimal-table)
    (org-weekly-schedule-append-column '("X" "Y"))
    (let ((cols-before (ows-test-count-columns)))
      (org-weekly-schedule-delete-last-column)
      (should (= (ows-test-count-columns) (1- cols-before))))))

(ert-deftest ows-test-delete-last-column-not-in-table ()
  "Deleting outside a table should signal user-error."
  (ows-test-with-org-buffer
    (insert "Not a table.\n")
    (should-error (org-weekly-schedule-delete-last-column)
                  :type 'user-error)))


;;; ======================================================================
;;; Tests: custom configuration
;;; ======================================================================

(ert-deftest ows-test-custom-time-slots ()
  "Changing time-slot config should alter scaffold structure."
  (let ((org-weekly-schedule-time-slots
         '(("08:00-09:00" "Morning:")
           ("09:00-10:00" nil)
           ("14:00-15:00" "Afternoon:")))
        (org-weekly-schedule-legend-keys '("X:")))
    ;; Slot count should reflect the override
    (should (= (org-weekly-schedule--slot-count) 3))
    ;; Base table should contain the custom labels
    (let ((tbl (org-weekly-schedule--base-table-string)))
      (should (string-match-p "Morning:" tbl))
      (should (string-match-p "Afternoon:" tbl))
      (should (string-match-p "08:00-09:00" tbl))
      (should-not (string-match-p "Generative:" tbl)))))

(ert-deftest ows-test-custom-legend-keys ()
  "Changing legend keys should alter the scaffold legend section."
  (let ((org-weekly-schedule-legend-keys '("P:" "Q:" "R:" "S:")))
    (let ((tbl (org-weekly-schedule--base-table-string)))
      (should (string-match-p "P:" tbl))
      (should (string-match-p "S:" tbl)))))


;;; ======================================================================
;;; Tests: round-trip integrity
;;; ======================================================================

(ert-deftest ows-test-round-trip-build-and-read ()
  "Build a week, then verify a specific cell deep in the table.
The research-heavy template puts B in slot 5 (13:15-14:45).
With the full scaffold, that is data row 10, column 2."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("M" . "research-heavy")))
    ;; Verify header
    (should (string= (ows-test-cell-value 1 1) "Time"))
    (should (string= (ows-test-cell-value 1 2) "M"))
    ;; Verify a Generative slot (row 3 = 04:00-05:30)
    (should (string= (ows-test-cell-value 3 2) "A"))
    ;; Verify category label row is blank in the day column
    (should (string= (ows-test-cell-value 2 2) ""))))

(ert-deftest ows-test-round-trip-two-columns-independent ()
  "Two different templates stamped side-by-side should not interfere."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("M"  . "research-heavy")
       ("Tu" . "light")))
    ;; research-heavy slot 0 = A; light slot 0 = ""
    (should (string= (ows-test-cell-value 3 2) "A"))
    (should (string= (ows-test-cell-value 3 3) ""))))


;;; ======================================================================
;;; Tests: date header
;;; ======================================================================

(ert-deftest ows-test-add-date-header-rows-added ()
  "Adding a date header should insert two extra data rows."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("M" . "research-heavy") ("Tu" . "balanced")))
    (let ((rows-before (ows-test-count-data-rows)))
      (org-weekly-schedule-add-date-header "2026-03-16")
      (should (= (ows-test-count-data-rows) (+ rows-before 2))))))

(ert-deftest ows-test-add-date-header-day-row-content ()
  "The Day row should contain the correct day abbreviation.
2026-03-16 is a Monday."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("M" . "research-heavy") ("Tu" . "balanced")))
    (org-weekly-schedule-add-date-header "2026-03-16")
    ;; Row 1 should be the Day row, column 1 = "Day"
    (should (string= (ows-test-cell-value 1 1) "Day"))
    ;; Column 2 should be "M" (Monday)
    (should (string= (ows-test-cell-value 1 2) "M"))
    ;; Column 3 should be "Tu" (Tuesday = 2026-03-17)
    (should (string= (ows-test-cell-value 1 3) "Tu"))))

(ert-deftest ows-test-add-date-header-date-row-content ()
  "The Date row should contain the correct day-of-month numbers.
2026-03-16 is the 16th."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("M" . "research-heavy") ("Tu" . "balanced")))
    (org-weekly-schedule-add-date-header "2026-03-16")
    ;; Row 2 should be the Date row
    (should (string= (ows-test-cell-value 2 1) "Date"))
    (should (string= (ows-test-cell-value 2 2) "16"))
    (should (string= (ows-test-cell-value 2 3) "17"))))

(ert-deftest ows-test-add-date-header-time-row-shifts ()
  "After adding the date header, the Time row should shift to row 3."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("M" . "research-heavy")))
    (org-weekly-schedule-add-date-header "2026-03-16")
    (should (string= (ows-test-cell-value 3 1) "Time"))))

(ert-deftest ows-test-add-date-header-column-count-unchanged ()
  "The date header should not change the number of columns."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("M" . "balanced") ("Tu" . "light")))
    (let ((cols-before (ows-test-count-columns)))
      (org-weekly-schedule-add-date-header "2026-03-16")
      (should (= (ows-test-count-columns) cols-before)))))

(ert-deftest ows-test-add-date-header-invalid-date ()
  "An invalid date format should signal user-error."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("M" . "balanced")))
    (should-error
     (org-weekly-schedule-add-date-header "March 16")
     :type 'user-error)))

(ert-deftest ows-test-add-date-header-not-in-table ()
  "Calling add-date-header outside a table should signal user-error."
  (ows-test-with-org-buffer
    (insert "No table here.\n")
    (should-error
     (org-weekly-schedule-add-date-header "2026-03-16")
     :type 'user-error)))

(ert-deftest ows-test-add-date-header-weekend-crossover ()
  "Dates that cross a weekend boundary should use correct abbreviations.
2026-03-20 is a Friday; 3 day columns should give F, Sa, Su."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("F" . "light") ("Sa" . "off") ("Su" . "off")))
    (org-weekly-schedule-add-date-header "2026-03-20")
    (should (string= (ows-test-cell-value 1 2) "F"))
    (should (string= (ows-test-cell-value 1 3) "Sa"))
    (should (string= (ows-test-cell-value 1 4) "Su"))
    (should (string= (ows-test-cell-value 2 2) "20"))
    (should (string= (ows-test-cell-value 2 3) "21"))
    (should (string= (ows-test-cell-value 2 4) "22"))))

(ert-deftest ows-test-build-week-with-date ()
  "build-week with a start-date should include Day/Date header rows."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("M" . "research-heavy") ("Tu" . "balanced"))
     "2026-03-16")
    ;; Should have Day and Date rows at top
    (should (string= (ows-test-cell-value 1 1) "Day"))
    (should (string= (ows-test-cell-value 2 1) "Date"))
    (should (string= (ows-test-cell-value 3 1) "Time"))))

(ert-deftest ows-test-build-week-without-date ()
  "build-week without a start-date should have Time as the first row."
  (ows-test-with-org-buffer
    (org-weekly-schedule-build-week
     '(("M" . "research-heavy")))
    (should (string= (ows-test-cell-value 1 1) "Time"))))


(provide 'org-weekly-schedule-test)
;;; org-weekly-schedule-test.el ends here
