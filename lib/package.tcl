namespace eval pkgtools {}

proc pkgtools::architecture {} {
	global tcl_platform
	if {[string equal $tcl_platform(platform) unix]} {
		return $tcl_platform(os)-$tcl_platform(machine)
	} else {
		return $tcl_platform(platform)-$tcl_platform(machine)
	}
}

proc ::pkgtools::findlib {dir name} {
	global tcl_platform noc
	if {"$tcl_platform(platform)" == "windows"} {
		set libpattern \{lib,\}$name\[0-9\]*[info sharedlibextension]
	} else {
		set libpattern lib${name}\[0-9\]*[info sharedlibextension]
	}
	set list [list [file join $dir [pkgtools::architecture] $libpattern]]
	if {[string equal $tcl_platform(platform) unix] && [regexp {^i|x.*86} $tcl_platform(machine)]} {
		set os $tcl_platform(os)
		foreach arch {x86* i*86} {
			lappend list [file join $dir $os-$arch $libpattern]
		}
	}	
	lappend list [file join $dir build $libpattern] \
		[file join $dir win $libpattern] \
		[file join $dir $libpattern] \
		[file join $dir .. $libpattern]
	foreach libfile $list {
		set libfile [lindex [glob -nocomplain $libfile] 0]
		if [file exists $libfile] {break}
	}
	return $libfile
}

proc ::pkgtools::init {dir name {testcmd {}} {noc_file {}} {packagename {}}} {
	global tcl_platform noc
	#
	# Try to find the compiled library in several places
	#
	if {[string equal $testcmd ""] || ![string equal [info commands $testcmd] $testcmd]} {
		#
		# Load the shared library if present
		# If not, Tcl code will be loaded when necessary
		#
		set libfile [::pkgtools::findlib $dir $name]
		if [file exists $libfile] {
			if {"[info commands $testcmd]" == ""} {
				if {$packagename eq ""} {
					namespace eval :: [list load $libfile]
				} else {
					namespace eval :: [list load $libfile $packagename]
				}
			}
		} else {
			if {![string equal $noc_file ""]} {
				set noc 1
				source [file join ${dir} $noc_file]
			} else {
				error "library not found"
			}
		}
	}
}

