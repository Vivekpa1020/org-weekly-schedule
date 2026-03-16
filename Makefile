# Makefile for org-weekly-schedule  -*- makefile-gmake -*-
#
# Targets:
#   make          — byte-compile the package
#   make test     — run the ERT test suite in batch mode
#   make lint     — byte-compile with extra warnings (acts as a linter)
#   make clean    — remove compiled .elc files
#   make all      — compile, then test
#
# Override EMACS on the command line to use a different Emacs binary:
#   make EMACS=/path/to/emacs test

EMACS   ?= emacs
BATCH    = $(EMACS) -Q --batch

# Source and test files
SRC      = org-weekly-schedule.el
TEST     = org-weekly-schedule-test.el
ELC      = $(SRC:.el=.elc)

.PHONY: all compile test lint clean

all: compile test

# ---- Byte-compile --------------------------------------------------------

compile: $(ELC)

%.elc: %.el
	$(BATCH) \
	  --eval '(setq byte-compile-error-on-warn nil)' \
	  -f batch-byte-compile $<

# ---- Run tests -----------------------------------------------------------

test:
	$(BATCH) \
	  -L . \
	  -l $(SRC) \
	  -l $(TEST) \
	  -f ert-run-tests-batch-and-exit

# ---- Lint (strict byte-compile) ------------------------------------------

lint:
	$(BATCH) \
	  --eval '(setq byte-compile-error-on-warn t)' \
	  -f batch-byte-compile $(SRC)
	@rm -f $(ELC)

# ---- Clean ---------------------------------------------------------------

clean:
	rm -f $(ELC)
