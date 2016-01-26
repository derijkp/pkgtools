namespace eval pkgtools {}
catch {package require platform}

proc pkgtools::architecture {} {
	global tcl_platform
	if {![catch {platform::generic} result]} {
		return $result
	}
	if {([string equal $tcl_platform(platform) unix] || [string equal $tcl_platform(platform) windows])
	    && ([regexp {^i|x.*86} $tcl_platform(machine)] || "$tcl_platform(machine)" == "intel")} {
		if {[string equal $tcl_platform(platform) windows]} {
			set os windows
		} else {
			set os [string tolower $tcl_platform(os)]
		}
		if {$tcl_platform(wordSize) == 4} {
			return $os-i686
		} else {
			return $os-x86_64
		}
	} elseif {[string equal $tcl_platform(platform) unix]} {
		return $tcl_platform(os)-$tcl_platform(machine)
	} else {
		return $tcl_platform(platform)-$tcl_platform(machine)
	}
}

proc ::pkgtools::findlib {dir name} {
	global tcl_platform noc
	if {"$tcl_platform(platform)" == "windows"} {
		set libpatterns [list \{lib,\}$name\[0-9.\]*[info sharedlibextension] \{lib,\}$name[info sharedlibextension]]
	} else {
		set libpatterns [list lib${name}\[0-9.\]*[info sharedlibextension] lib${name}[info sharedlibextension]]
	}
	foreach libpattern $libpatterns {
		set libfile [file join $dir [pkgtools::architecture] $libpattern]
		set libfile [lindex [glob -nocomplain $libfile] 0]
		if {[file exists $libfile]} {return $libfile}
	}
	if {([string equal $tcl_platform(platform) unix] || [string equal $tcl_platform(platform) windows])
	    && ([regexp {^i|x.*86} $tcl_platform(machine)] || "$tcl_platform(machine)" == "intel")} {
		if {[string equal $tcl_platform(platform) windows]} {
			set oss {Windows windows win win32}
		} else {
			set oss [list $tcl_platform(os) [string tolower $tcl_platform(os)]]
		}
		if {$tcl_platform(wordSize) == 4} {
			set order {i*86 x86* intel}
		} else {
			set order {x86* i*86 intel}
		}
		foreach os $oss {
			foreach arch $order {
				foreach libpattern $libpatterns {
					set libfile [file join $dir $os-$arch $libpattern]
					set libfile [lindex [glob -nocomplain $libfile] 0]
					if {[file exists $libfile]} {return $libfile}
				}
			}
		}
	}
	foreach libfile [list [file join $dir build] \
		[file join $dir win] \
		$dir \
		[file join $dir ..]] {
			foreach libpattern $libpatterns {
				set libfile [lindex [glob -nocomplain [file join $libfile $libpattern]] 0]
				if {[file exists $libfile]} {return $libfile}
			}
	}
	return {}
}

proc ::pkgtools::findexe {dir name} {
	global tcl_platform noc
	if {"$tcl_platform(platform)" == "windows"} {
		set libpatterns [list $name.exe $name\[0-9.\]*.exe]
	} else {
		set libpatterns [list $name ${name}\[0-9.\]*]
	}
	foreach libpattern $libpatterns {
		set libfile [file join $dir [pkgtools::architecture] $libpattern]
		set libfile [lindex [glob -nocomplain $libfile] 0]
		if {[file exists $libfile]} {return $libfile}
	}
	if {([string equal $tcl_platform(platform) unix] || [string equal $tcl_platform(platform) windows])
	    && ([regexp {^i|x.*86} $tcl_platform(machine)] || "$tcl_platform(machine)" == "intel")} {
		if {[string equal $tcl_platform(platform) windows]} {
			set oss {Windows windows win win32}
		} else {
			set oss [list $tcl_platform(os) [string tolower $tcl_platform(os)]]
		}
		if {$tcl_platform(wordSize) == 4} {
			set order {i*86 x86* intel}
		} else {
			set order {x86* i*86 intel}
		}
		foreach os $oss {
			foreach arch $order {
				foreach libpattern $libpatterns {
					set libfile [file join $dir $os-$arch $libpattern]
					set libfile [lindex [glob -nocomplain $libfile] 0]
					if {[file exists $libfile]} {return $libfile}
				}
			}
		}
	}
	foreach libfile [list [file join $dir build] \
		[file join $dir win] \
		$dir \
		[file join $dir ..]] {
			foreach libpattern $libpatterns {
				set libfile [lindex [glob -nocomplain [file join $libfile $libpattern]] 0]
				if {[file exists $libfile]} {return $libfile}
			}
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

