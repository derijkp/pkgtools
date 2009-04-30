namespace eval pkgtools {}

namespace eval pkgtools {
	namespace export test testsummarize testleak testfloats
}

proc pkgtools::display {e} {
	puts $e
}

proc pkgtools::logerror {group description errormessage} {
	variable errors
	display $errormessage
	lappend errors [list $group $description $errormessage]
}

proc pkgtools::logskip {group description condition} {
	variable skipped
	display "** skipped $group: $description ([lindex $condition 1])"
	lappend skipped [list $group $description $condition]
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
	variable errors
	variable skipped
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
	set error [catch {_pkgtools__tools__try} result]
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
		set compar [expr {"$result"=="$expected"}]
		set errorbetween {should be}
	}
	if {!$compar} {
		if [info exists ::env(TCL_TEST_ONLYERRORS)] {display "-- test $f: $description --"}
		logerror $group $description "error: result is:\n$result\n$errorbetween\n$expected"
	}
	if {$testleak} {
		set line1 [lindex [split [exec ps l [pid]] "\n"] 1]
		time {set error [catch {tools__try $object} result]} $testleak
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

proc pkgtools::testsummarize {} {
	variable errors
	variable skipped
	if [info exists errors] {
		global currenttest
		if [info exists currenttest] {
			set error "***********************\nThere were errors in testfile $currenttest"
		} else {
			set error "***********************\nThere were errors in the tests"
		}
		foreach line $errors {
			foreach {group descr errormessage} $line break
			append error "\n$group: $descr  ----------------------------"
			append error "\n$errormessage"
		}
		# display $error
		if {[info exists skipped]} {
			append error "\n***********************\nskipped [llength $skipped]"
		}
		return -code error $error
	} elseif {[info exists skipped]} {
		set result "All tests ok (skipped [llength $skipped])"
	} else {
		set result "All tests ok"
	}
	puts $result
	return $result
}
