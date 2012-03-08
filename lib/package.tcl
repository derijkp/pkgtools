namespace eval pkgtools {}
catch {package require platform}

proc pkgtools::architecture {} {
	global tcl_platform
	if {![catch {platform::generic} result]} {
		return $result
	}
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
	set libfile [file join $dir [pkgtools::architecture] $libpattern]
	set libfile [lindex [glob -nocomplain $libfile] 0]
	if {[file exists $libfile]} {return $libfile}
	if {([string equal $tcl_platform(platform) unix] || [string equal $tcl_platform(platform) windows])
	    && ([regexp {^i|x.*86} $tcl_platform(machine)] || "$tcl_platform(machine)" == "intel")} {
		set oss [list $tcl_platform(os) [string tolower $tcl_platform(os)]]
		if {$tcl_platform(wordSize) == 4} {
			set order {i*86 x86*}
		} else {
			set order {x86* i*86}
		}
		foreach os $oss {
			foreach arch $order {
				set libfile [file join $dir $os-$arch $libpattern]
				set libfile [lindex [glob -nocomplain $libfile] 0]
				if {[file exists $libfile]} {return $libfile}
			}
		}
	}
	foreach libfile [list [file join $dir build $libpattern] \
		[file join $dir win $libpattern] \
		[file join $dir $libpattern] \
		[file join $dir .. $libpattern]] {
		set libfile [lindex [glob -nocomplain $libfile] 0]
		if {[file exists $libfile]} {return $libfile}
	}
	return {}
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

