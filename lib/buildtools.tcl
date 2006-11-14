namespace eval pkgtools {}

proc ::pkgtools::copy {args} {
	puts "copy $args"
	eval file copy -force $args
}

proc ::pkgtools::compiledir {dir} {
	puts "compiling $dir"
	foreach file [glob -nocomplain $dir/*.tcl] {
		if {[string equal {init.tcl} [file tail $file]]} continue
		puts $file
		puts [exec tclcompiler -verbose -nologo -force $file]
		file delete $file
		catch {file delete ${file}~}
	}
	catch {eval file delete [glob $dir/*~]}
	foreach file [glob -nocomplain $dir/*] {
		if {[file isdir $file]} {
			compiledir $file
		}
	}
	catch {
		set c [file_read $dir/tclIndex]
		regsub -all {\.tcl} $c .tbc c
		file_write $dir/tclIndex $c
	}
}

proc ::pkgtools::tbccopy {args} {
	puts "copy $args"
	eval file copy -force $args
	set dest [lindex $args end]
	foreach dir [lrange $args 0 end-1] {
		compiledir [file join $dest [file tail $dir]]
	}
}

proc ::pkgtools::del {file} {
	if {![file exists $file]} return
	puts "deleting $file"
	file delete -force $file
}

proc ::pkgtools::get {varName {default {}}} {
	if {[uplevel [list info exists $varName]]} {
		return [uplevel [list set $varName]]
	} else {
		return $default
	}
}

proc ::pkgtools::file_read {file} {
	set f [open $file]
	set c [read $f]
	close $f
	return $c
}

proc ::pkgtools::file_write {file data} {
	set f [open $file w]
	puts -nonewline $f $data
	close $f
}

proc ::pkgtools::version {{argv {}}} {
	global tcl_platform libfiles shareddatafiles headers libbinaries binaries version
	set len [llength $argv]
	if {$len != 0} {
		error "use:\nversion.tcl"
	}
	if {[info exists ::srcdir]} {
		set srcdir $::srcdir
	} else {
		set srcdir [file normalize [file join [file dir [info script]] ..]]
	}
	if {[info exists version]} {
		foreach {majorversion minorversion patchlevel} [split $version .] break
	} elseif {[file exists $srcdir/configure.in]} {
		set f [open $srcdir/configure.in]
		set c [read $f]
		close $f
		# regexp {\npackage ifneeded [^ ]+ ([^ ]+)} $c temp version
		if {[regexp {MAJOR_VERSION=([^ \n]+)} $c temp majorversion]} {
			regexp {MINOR_VERSION=([^ \n]+)} $c temp minorversion
			regexp {PATCHLEVEL=([^ \n]*)} $c temp patchlevel
		} else {
			regexp {AC_INIT\(\[.*\], *\[([^.]+)\.([^.]+)\.([^.]+)\]\)} $c temp majorversion minorversion patchlevel
		}
	} elseif {[file exists $srcdir/init.tcl]} {
		set f [open $srcdir/init.tcl]
		set c [read $f]
		close $f
		regexp {provide +[^ \n]+ +([0-9.]+)} $c temp v
		foreach {majorversion minorversion patchlevel} [split $v .] break
	} else {
		error "no configure.in or init.tcl found in $srcdir"
	}
	if {$patchlevel ne ""} {
		set version $majorversion.$minorversion.$patchlevel
	} else {
		set version $majorversion.$minorversion
		set patchlevel 0
	}
	if {![catch {set files [exec grep -rl {\$Format: } $srcdir]}]} {
		foreach file [split $files \n] {
			if {[string match "$srcdir/_darcs*" $file]} {
				continue
			}
			puts "updating versions in $file"
			set c [split [file_read $file] \n]
			set pos 0
			foreach line $c {
				incr pos
				if {[regexp {\$Format: "(.*)"\$} $line temp string]} {
					regsub -all {\$ProjectMajorVersion[^$]*\$} $string $majorversion string
					regsub -all {\$ProjectMinorVersion[^$]*\$} $string $minorversion string
					regsub -all {\$ProjectPatchLevel[^$]*\$} $string $patchlevel string
					set string [string map [list \\\" \" \\\\ \\] $string] 
					regsub -all {\\"} $string \" string
					set c [lreplace $c $pos $pos $string]
				}
			}
			file_write $file [join $c \n]
		}
	}
	if {[file exists $srcdir/DESCRIPTION.txt]} {
		puts "Changing version in $srcdir/DESCRIPTION.txt"
		set c [file_read $srcdir/DESCRIPTION.txt]
		regsub {Version: [0-9.]+} $c "Version: $version" c
		file copy -force $srcdir/DESCRIPTION.txt $srcdir/DESCRIPTION.txt~
		file_write $srcdir/DESCRIPTION.txt $c
		file delete $srcdir/DESCRIPTION.txt~
	}
	if {[file exists $srcdir/lib/init.tcl]} {
		puts "Changing version in $srcdir/lib/init.tcl"
		set c [file_read $srcdir/lib/init.tcl]
		regsub -all {::version [0-9.]+} $c "::version $majorversion.$minorversion" c
		regsub -all {::patchlevel [0-9.]+} $c "::patchlevel $patchlevel" c
		file copy -force $srcdir/lib/init.tcl $srcdir/lib/init.tcl~
		file_write $srcdir/lib/init.tcl $c
		file delete $srcdir/lib/init.tcl~
	}
	if {[file exists $srcdir/pkgIndex.tcl]} {
		puts "Changing version in $srcdir/pkgIndex.tcl"
		set c [file_read $srcdir/pkgIndex.tcl]
		regsub {package ifneeded ([^ ]+) [0-9.]+} $c "package ifneeded \\1 $majorversion.$minorversion" c
		file copy -force $srcdir/pkgIndex.tcl $srcdir/pkgIndex.tcl~
		file_write $srcdir/pkgIndex.tcl $c
		file delete $srcdir/pkgIndex.tcl~
	}
	foreach file [glob $srcdir/*.tcl] {
		if {[lsearch [list $srcdir/lib/init.tcl $srcdir/pkgIndex.tcl] $file] != -1} continue
		puts "Changing version in $file"
		set c [file_read $file]
		regsub {set Classy::appversion [0-9.]+} $c "set Classy::appversion $majorversion.$minorversion" c
		regsub {extension provide ([^ ]+) [0-9.]+} $c "extension provide \\1 $version" c
		file copy -force $file $file~
		file_write $file $c
		file delete $file~
	}
	return [list $majorversion $minorversion $patchlevel]
}	

proc ::pkgtools::install {argv} {
	global tcl_platform libfiles tbclibfiles shareddatafiles headers libbinaries binaries extname
	foreach v {libfiles tbclibfiles shareddatafiles headers libbinaries binaries} {
		if {![info exists $v]} {set $v {}}
	}
	foreach {majorversion minorversion patchlevel} [::pkgtools::version] break
	set len [llength $argv]
	if {$len == 0} {
		error "use either:\ninstall.tcl installdir\nor\ninstall.tcl pkglibdir <pkglibdir> pkgtcllibdir <pkgtcllibdir> pkgdatadir <pkgdatadir> pkgincludedir <pkgincludedir> bindir <bindir> mandir <mandir>"
	} elseif {$len == 1} {
		if {[info exists ::srcdir]} {
			set config(srcdir) $::srcdir
		} else {
			set config(srcdir) [file normalize [file join [file dir [info script]] ..]]
		}
		set pkglibdir [file normalize [lindex $argv 0]]
		if {[file isdir $pkglibdir]} {
			if {[info exists extname]} {
				set pkglibdir [file join $pkglibdir $extname]
			} else {
				set pkglibdir [file join $pkglibdir [string trimright [file tail $config(srcdir)] 012345678.]]
			}
		}
		if {[regexp {[0-9]$} $pkglibdir]} {
			append pkglibdir -$majorversion.$minorversion.$patchlevel
		} else {
			append pkglibdir $majorversion.$minorversion.$patchlevel
		}
		if {[file exists $pkglibdir]} {
			return -code error "\"$pkglibdir\" already exists"
		}
		set config(pkglibdir) $pkglibdir
		set config(pkgdatadir) $pkglibdir/shared
		set config(pkgincludedir) $pkglibdir/include
		set config(bindir) $pkglibdir/bin
	} else {
		array set config $argv
	}
	catch {file delete -force $config(pkglibdir)}
	file mkdir $config(pkglibdir)
	foreach file $libfiles {
		copy $config(srcdir)/$file $config(pkglibdir)
	}
	foreach file $tbclibfiles {
		tbccopy $config(srcdir)/$file $config(pkglibdir)
	}

	# install shared data files
	if {[llength $shareddatafiles]} {
		file mkdir $config(pkgdatadir)
		foreach file $shareddatafiles {
			copy $config(srcdir)/$file $config(pkgdatadir)
		}
	}
	# install headers
	if {[llength $headers]} {
		file mkdir $config(pkgincludedir)
		foreach file $headers {
			copy $file $config(pkgincludedir)
		}
	}
	# install docs
	if {[info exists config(mandir]} {
		if {[string equal $tcl_platform(platform) unix]} {
			set manfiles [glob -nocomplain $config(srcdir)/docs/man/*.n]
			if {[llength $manfiles]} {
				file mkdir $config(mandir)/mann
				eval file copy -force $manfiles $config(mandir)/mann
			}
		}
	}
	catch {file copy -force $config(srcdir)/docs $config(pkglibdir)}
	
	# install lib binaries
	if {[llength $libbinaries]} {
		set dir $config(pkglibdir)/[pkgtools::architecture]
		file mkdir $dir
puts "$libbinaries $dir"
		foreach binary $libbinaries {
			if {[file exists $binary]} {
				copy $binary $dir
				set root [file root $binary]
				if {[file exists $root.lib]} {
					copy $root.lib $dir
				}
			}
		}
	}
	# install bin binaries
	if {[llength $binaries]} {
		file mkdir $config(bindir)
		foreach binary $binaries {
			if {[file exists $config(srcdir)/$binary]} {
				copy $config(srcdir)/$binary $config(bindir)
				catch {file attributes $config(bindir)/$binary -permissions 644}
			}
		}
	}
}	


proc ::pkgtools::uninstall {argv} {
	global tcl_platform
	set libfiles [get config(libfiles) ""]
	set shareddatafiles [get config(shareddatafiles) ""]
	set headers [get config(headers) ""]
	set libbinaries [get config(libbinaries) ""]
	set binaries [get config(binaries) ""]
	array set config $argv
	# delete libfiles
	del $config(pkglibdir)
	
	# delete shared data files
	foreach file $shareddatafiles {
		del $config(pkgdatadir)/$file
	}
	
	# delete headers
	foreach file $headers {
		del $config(pkgincludedir)/$file
	}
	
	# delete docs
	foreach file [glob -nocomplain $config(srcdir)/doc/man/*.n] {
		del $config(mandir)/mann/[file tail $file]
	}
	
	# delete bin binaries
	file mkdir $config(bindir)
	foreach binary $binaries {
		del $config(bindir)/$binary
	}
}

proc ::pkgtools::tmml2html {src dst} {
	set f [open $src]
	set data [read $f]
	close $f
	regexp {<name>(.*?)</name>} $data temp title
	regexp {<desc>(.*?)</desc>} $data temp desc
	regsub {^.*</namesection>} $data {} data
	regsub -all {<ref>(.*?)</ref>} $data {<a href="\1.html">\1</a>} data
	set data [string map {
		</manpage> {}
		<section> {} </section> {}
		<title> <h2> </title> </h2>
		<seealso> {<h2>SEE ALSO</h2><ul>}
		</seealso> </ul>
		<keywords> {<h2>KEYWORDS</h2><ul>}
		</keywords> </ul>
		<keyword> <li>
		</keyword> </li>
		<commandlist> <dl> </commandlist> </dl> <commanddef> {} </commanddef> {}
		<command> <dt> </command> </dt> <desc> <dd> </desc> </dd>
		<cmd> <i> </cmd> </i> <m> <b> </m> </b>
		<dle> {} </dle> {}
		<optlist> <dl> </optlist> </dl> <optdef> {} </optdef> {}
		<optname> <dt><b> </optname> {</b> } <optarg> {} </optarg> </dt>
		<method> <i> </method> </i> <example> <pre> </example> </pre>
		$ \\$ \[ \\\[ \] \\\]
	} $data]
#	set data "\[header \"$title\"\]$data\[footer\]"
	set f [open $dst w]
	puts $f $data
	close $f
}

proc ::pkgtools::makedoc {{dir {}}} {
	if {$dir ne ""} {
		cd $dir
	}
	set tmml-man [file join $pkgtools::dir bin tmml-man.tcl]
	foreach file [glob -nocomplain docs/xml/*.xml] {
		set destfile [file join docs man [file tail [file root $file]]].n
		if {![file exists $destfile] || ([file mtime $file] > [file mtime $destfile])} {
			puts "creating $destfile"
			if {[catch {exec ${tmml-man} $file > $destfile} result]} {
				puts error:$result
			}
		}
		set destfile [file join docs html [file tail [file root $file].html]]
		if {![file exists $destfile] || ([file mtime $file] > [file mtime $destfile])} {
			puts "creating $destfile"
			if {[catch {tmml2html $file $destfile} result]} {
				puts error:$result
			}
		}
	}
}
