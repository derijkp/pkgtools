#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" "$@"

set script [file normalize [info script]]
if {"$tcl_platform(platform)"=="unix"} {
	while 1 {
		if {[catch {set script [file normalize [file readlink $script]]}]} break
	}
}
lappend auto_path [file dir $script]

# settings
# --------

set srcdir [file dir $script]
set libfiles {lib init.tcl pkgIndex.tcl}
set shareddatafiles {}
set headers {}
set libbinaries {}
set binaries {}

# standard
# --------
package require pkgtools
pkgtools::install $argv

