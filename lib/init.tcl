# This file provides for an alternative loading of extensions
# based on directory.
# in order to load the given package, this file is sourced
# When this script is sourced, the variable $dir must contain the
# full path name of the extensions directory.

namespace eval ::pkgtools {}
if {![info exists ::pkgtools::dir]} {
	set ::pkgtools::dir $dir
}

# $Format: "set ::pkgtools::version $ProjectMajorVersion$.$ProjectMinorVersion$"$
set ::pkgtools::version 0.9
# $Format: "set ::pkgtools::patchlevel $ProjectPatchLevel$"$
set ::pkgtools::patchlevel 0

package provide pkgtools $::pkgtools::version

source [file join $::pkgtools::dir lib package.tcl]
set ::auto_index(::pkgtools::install) [list source [file join $::pkgtools::dir lib buildtools.tcl]]
set ::auto_index(::pkgtools::uninstall) [list source [file join $::pkgtools::dir lib buildtools.tcl]]
set ::auto_index(::pkgtools::version) [list source [file join $::pkgtools::dir lib buildtools.tcl]]

proc pkgtools::startdir {} {
	if {[info exists ::pkgtools::startdir]} {
		return $::pkgtools::startdir
	}
	set script [file normalize [info script]]
	if {"$script"==""} {
		set ::pkgtools::startdir [file normalize .]
	} else {
		if {"$::tcl_platform(platform)"=="unix"} {
			while 1 {
				if {[catch {set script [file normalize [file readlink $script]]}]} break
			}
		}
		set ::pkgtools::startdir [file dir $script]
	}
}
