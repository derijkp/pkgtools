# This file provides for an alternative loading of extensions
# based on directory.
# in order to load the given package, this file is sourced
# When this script is sourced, the variable $dir must contain the
# full path name of the extensions directory.

namespace eval ::pkgtools {}
set ::pkgtools::dir $dir
source [file join $dir lib init.tcl]
extension provide pkgtools 0.9
