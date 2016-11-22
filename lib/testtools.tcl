namespace eval pkgtools {}

namespace eval pkgtools {
	namespace export teststart test testfile testsummarize testleak testfloats
}

proc pkgtools::display {e} {
	puts $e
}

proc pkgtools::logerror {group description errormessage} {
	variable errors
	variable currenttest
	display $errormessage
	lappend errors([get currenttest ""]) [list $group $description $errormessage]
}

proc pkgtools::logskip {group description condition} {
	variable errors
	variable currenttest
	display "** skipped $group: $description ([lindex $condition 1])"
	lappend skipped([get currenttest ""]) [list $group $description $condition]
}

proc pkgtools::testleak {{number {}}} {
	variable testleak
	if {$number eq ""} {
		return $testleak
	} else {
		set testleak $number
	}
}

proc pkgtools::testfloats {list1 list2 {accuracy 1e-5}} {
	if {[llength $list1] != [llength $list2]} {return 0}
	foreach e1 $list1 e2 $list2 {
		if {[expr {abs($e2-$e1)}] > $accuracy} {return 0}
	}
	return 1
}

proc pkgtools::test {group description script expected args} {
	variable testleak
	upvar version version
	upvar opt opt
	if {![info exists testleak]} {set testleak 0}
	foreach arg $args {set options($arg) 1}
	set conditions [array names options {skipon *}]
	if {[llength $conditions]} {
		foreach condition $conditions {
			if {[expr [lindex $condition 1]]} {
				logskip $group $description $condition
				return
			}
		}
	}
	if {[info exists options(error)]} {set causeerror 1} else {set causeerror 0}
	set e "testing $group: $description"
	if {![info exists ::env(TCL_TEST_ONLYERRORS)]} {display $e}
	append code $script
	namespace eval :: [list proc _pkgtools__tools__try {} $script]
	set keeppwd [pwd]
	set error [catch {_pkgtools__tools__try} result]
	cd $keeppwd
	if {$causeerror} {
		if {!$error} {
			if {[info exists ::env(TCL_TEST_ONLYERRORS)]} {display "-- test $group: $description --"}
			logerror $group $description "test should cause an error\nresult is \n$result"
			return
		}	
	} else {
		if {$error} {
			if {[info exists ::env(TCL_TEST_ONLYERRORS)]} {display "-- test $group: $description --"}
			logerror $group $description "test caused an error\nerror is \n$result\n"
			return
		}
	}
	
	if {[info exists options(regexp)]} {
		set compar [regexp $expected $result]
		set errorbetween {should match (regexp)}
	} elseif {[info exists options(match)]} {
		set compar [string match $expected $result]
		set errorbetween {should match}
	} else {
		set compar [expr {"$result" eq "$expected"}]
		set errorbetween {should be}
	}
	if {!$compar} {
		if [info exists ::env(TCL_TEST_ONLYERRORS)] {display "-- test $f: $description --"}
		logerror $group $description "error: result is:\n$result\n$errorbetween\n$expected"
	}
	if {$testleak} {
		set line1 [lindex [split [exec ps l [pid]] "\n"] 1]
		set keeppwd [pwd]
		time {set error [catch {tools__try $object} result]} $testleak
		cd $keeppwd
		set line2 [lindex [split [exec ps l [pid]] "\n"] 1]
		if {([lindex $line1 6] != [lindex $line2 6])||([lindex $line1 7] != [lindex $line2 7])} {
			if {![info exists options(noleak)]} {
				if [info exists ::env(TCL_TEST_ONLYERRORS)] {display "-- test $group: $description --"}
				puts "possible leak:"
				puts $line1
				puts $line2
				puts "\n"
			}
		}
	}
	return
}

proc pkgtools::testfile {file} {
	variable errors
	variable currenttest
	global env
	if [info exists env(TCL_TEST_DIR)] {
		cd $env(TCL_TEST_DIR)
	}
	set currenttest $file
	puts "-----------------------------------------------------"
	puts "Test file $file"
	puts "-----------------------------------------------------"
	set e [catch {uplevel #0 source $file} result]
	if {$e} {
		puts "error sourcing file $file: $result"
		lappend errors($file) [list $file source "error sourcing file $file" $result]
	}
	unset currenttest
}

proc pkgtools::teststart {} {
	variable errors
	variable skipped
	unset -nocomplain errors
	unset -nocomplain skipped
	set errors() {}
}

proc pkgtools::testsummarize {} {
	variable errors
	variable skipped
	variable currenttest
	if {[info exists currenttest]} {
		set skippednr [get skipped($currenttest) 0]
		if {![info exists errors($currenttest)]} {
			if {$skippednr} {
				puts "All tests ok (skipped $skippednr)"
			} else {
				puts "All tests ok"
			}
			return {}
		}
		set errorfiles $currenttest
	} else {
		set skippednr 0
		foreach file [array names skipped] {incr skippednr $skipped($file)}
		puts ****************************************
		set errorfiles [array names errors]
		if {![llength [get errors() ""]] && ([llength $errorfiles] <= 1)} {
			if {$skippednr} {
				puts "All tests ok (skipped $skippednr)"
			} else {
				puts "All tests ok"
			}
			if {[llength [info commands ::tk::button]]} {
				exit
			} else {
				return {}
			}
		}
	}
	set result ""
	foreach file $errorfiles {
		if {![llength $errors($file)]} continue
		if {$file ne ""} {
			set error "----------------------------------------\nThere were errors in testfile $file"
		} else {
			set error "----------------------------------------\nThere were errors in the tests"
		}
		foreach line $errors($file) {
			foreach {group descr errormessage} $line break
			append error "\n$group: $descr  ----------------------------"
			append error "\n$errormessage"
		}
		# display $error
		append result $error\n
	}
	if {$skippednr} {
		append result "Skipped $skippednr tests"
	}
	puts $result
	if {![info exists currenttest] && [llength [info commands ::tk::button]]} {
		exit
	} else {
		return $result
	}
}

