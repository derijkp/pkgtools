#!/bin/sh
# the next line restarts using wish \
exec tclsh "$0" "$@"

package require pkgtools
namespace import pkgtools::*

# pkgtools::testleak 100

test pkgtools::test {basic} {
	set a 1
} {1}

test pkgtools::test {error} {
	set a
} {can't read "a": no such variable} error

test pkgtools::test {error when there shouldn't be} {
	set a
} {can't read "a": no such variable}

test pkgtools::test {skipon skip test} {
	set a 1
} {2} [list skipon 1]

test pkgtools::test {error} {
	set a 1
} {1} [list skipon 0]

test pkgtools::test {testfloats} {
	set result {}
	lappend result [testfloats 1 1]
	lappend result [testfloats 1 4]
	lappend result [testfloats 1.0 1.00001]
	lappend result [testfloats {0.1} {0.1 1.0}]
	lappend result [testfloats 1.0 1.000000000000000000000000001]
	lappend result [testfloats {0.1 1.00001} {0.1 1.0}]
	lappend result [testfloats {0.1 0.99999999999999999999999999999} {0.1 1.0}]
} {1 0 0 0 1 0 1}

testsummarize


