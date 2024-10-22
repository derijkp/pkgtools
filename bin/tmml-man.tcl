#!/bin/sh
######################################################################
# $Id: tmml-man.tcl,v 1.6 2002/06/24 20:54:10 jenglish Exp $
# Created: 9 Aug 2000
# Copyright (C) 2000, Joe English.  All rights reserved.
######################################################################
# \
    exec tclsh $0 "$@"
#
# Description:
#	Convert TMML manpages to NROFF.
#
#
# TODO:
#	Possibly: change "STANDARD OPTIONS" back to ".SO" / ".SE"
#	Possibly: option to use different set of man.macros
#		(could improve .AP for instance)
#
#	Make sure that all diversions are initialized; otherwise
#	this can lead to hard errors on invalid input
#

lappend auto_path /usr/local/lib
set libdir [file dirname [info script]]
source [file join $libdir lpd.tcl]
source [file join $libdir translate.tcl]

package require cmdline

# NB: -version specified on the command line overrides
# 'version' attribute in manpage.

variable optlist {
    {output.arg		"-" 	"Write output to specified file" }
    {manual.arg		"" 	"Manual volume title" }
    {package.arg	"" 	"Package name" }
    {version.arg	""	"Package version" }
    {newsince.arg	""	"Add version information for version" }
    {soelim			"Copy 'man.macros' to output directly?" }
    {verbose			"Be verbose?" }
    {debuglpd			"Debug LPD?" }
    {directory.arg 	.	"Output directory (NYI)" }
    {lpd.arg		""	"Extra LPD to load" }
}

array set options [cmdline::getoptions ::argv $::optlist]


######################################################################
#
# Output routines:
#

# troffRequest name ?arg ...?" --
#	Outputs a TROFF request.
# 	'args' are output literally.

proc troffRequest {name args} {
    translate::flush;
    set line "$name"
    foreach arg $args {
	if {[regexp -- {^[\w]+$} $arg]} {
	    append line " $arg"
	} else {
	    append line " \"$arg\""
	}
    }
    translate::writeln $line
}

# proc troffOutput --
#	Output routine for TROFF text.
#	Makes sure that there are no leading blanks or blank lines
#	(which cause a paragraph break in *roff),
#	and protects initial "." and "'" (which would be
#	interpreted as a request)
#

proc troffProtect {line} {
    switch -- [string range $line 0 0] {
	"\\" -
	"." -
	"'" { set line "\\&$line" }
    }
    return $line
}

proc troffOutput {text} {
    foreach line [split $text "\n"] {
	set line [troffProtect [string trim $line]]
	if {[string length $line]} { translate::writeln $line }
    }
}

# nofillOutput --
#	Output routine for text to be processed in "no-fill" mode;
#	This preserves leading whitespace and all linebreaks.
#
proc nofillOutput {text} {
    foreach line [split $text "\n"] {
	translate::writeln [troffProtect $line]
    }
}

# string map for TROFF output:
#	Replaces special characters with appropriate TROFF escape codes.
#	%%% Lots more I think...
#
translate::stringmap troff {
	"\\"	"\\e"
	"\t"	" "
}

# string map for troff arguments:
#	Same as 'troff' string map, but also protects newlines
#	and (%%%incorrectly) '"' character.
#
translate::stringmap troffarg [translate::stringmap troff]
translate::stringmap troffarg [list \" \\*(lq "\n" " "]

# includeManMacros --
#	Include standard Tcl "man.macros", either by reference (default)
#	or a copy (if -soelim option is specified)
#
proc includeManMacros {} {
    variable options
    if {$options(soelim)} {
	global libdir
	set fp [open [file join $libdir man.macros] r]
	translate::writeln {'\" BEGIN man.macros}
	while {[gets $fp line] >= 0} {
	    if {[string match {'\\"*} $line]} { continue }
	    translate::writeln $line
	}
	translate::writeln {'\" END man.macros}
    } else {
    	translate::writeln ".so man.macros"
    }
}

# writeTitleLine --
#	Generate .TH header based on <manpage> attributes
#	and command-line options
#
proc writeTitleLine {} {
    variable tmml2man
    variable options
    variable manvolnum
    set title $tmml2man(@title)
    set section $manvolnum(#DEFAULT)
    if {[info exists manvolnum($tmml2man(@cat))]} {
	set section $manvolnum($tmml2man(@cat))
    }
    set date $tmml2man(@version)
    if {[string length $options(version)]} {
	set date $options(version)
    }
    if {[string length $options(package)]} {
	set source $options(package)
    } elseif {[info exists tmml2man(@package)] 
    	   && [string length $tmml2man(@package)]
    } {
	set source $tmml2man(@package)
    } else {
    	set source "Tcl"
    }

    set manual $options(manual)
    troffRequest .TH $title $section $date $source $manual
}

######################################################################
#
# Miscellaneous gubbage:
#
# By convention, the initial sections of Tcl/Tk manpages
#	(see variable boxedSections) are placed inside a
#	.BS/.BE environment, which draws a box.
#

variable manstate

set manstate(inBS) 0
variable boxedSections [list \
    NAME SYNOPSIS ARGUMENTS "STANDARD OPTIONS" "WIDGET-SPECIFIC OPTIONS"]

proc sectionHeading {title} {
    variable manstate
    variable boxedSections
    if {$manstate(inBS) && [lsearch $boxedSections $title] == -1} {
    	troffRequest .BE
	set manstate(inBS) 0
    }
    troffRequest .SH $title
}

# Relative indents:
#
#	TMML allows block-level elements like lists to be nested.
#	In the output, nested elements must be surrounded by
#	.RS / .RE pairs to ensure consitent indentation.
#
#	We handle this by keeping track of an "indent level",
#	inside block containers, the indent level is incremented by one,
# 	and we ensure that block elements appear only at even-numbered
#	indent levels, inserting .RS/.RE as needed.
#

set manstate(rsLevel) 0

proc beStart {} {
    variable manstate;
    if {$manstate(rsLevel) % 2} {
    	troffRequest .RS
	incr manstate(rsLevel)
    }
}
proc beEnd {} {
    translate::flush
    # .RE is generated at end of block container
}
proc bcStart {} {
    variable manstate;
    if {$manstate(rsLevel) % 2} {
    	puts stderr "INTERNAL ERROR: indent level=$manstate(rsLevel)"
    }
    incr manstate(rsLevel)
}
proc bcEnd {} {
    variable manstate
    incr manstate(rsLevel) -1
    if {$manstate(rsLevel) % 2} {
	troffRequest .RE
	incr manstate(rsLevel) -1
    }
}

# Version identification:
#
# Insert .VS and .VE requests if the current element has a 'version'
# attribute later or equal to the -newsince argument.
#

proc do.VS {} {
    global tmml2man options
    if {    [string length $options(newsince)]
         && [string length $tmml2man(@version)]
	 && [package vcompare $options(newsince) $tmml2man(@version)] <= 0
    } {
	troffRequest .VS $tmml2man(@version)
    	set tmml2man(in.VS) 1
    }
}

proc do.VE {} {
    global tmml2man options
    if {$tmml2man(in.VS)} {
    	troffRequest .VE $tmml2man(@version)
    }
}

######################################################################
#
# Specification:
#
#
translate::lpd tmml2man

lpd::attlist tmml2man {
    font	#INHERIT "R"

    @title	#DEFAULT ""
    @version	#DEFAULT ""
    @cat	#DEFAULT ""

    @cols	#INHERIT 1

    in.VS	#DEFAULT 0
    @version	#DEFAULT ""
}

array set manvolnum {
    fun 	3
    type 	3
    syscmd 	1
    #DEFAULT	n
}

lpd::linkset tmml2man #INITIAL {
    manpage {
   	ignorews 	1
	stringmap	troff
	outputProc	troffOutput
	startAction {
	    translate::writeln {'\"}
	    translate::writeln "'\\\" Generated from $tmml2man(sourceFile)"
	    translate::writeln {'\"}
	    includeManMacros
	    writeTitleLine
	}
    }

    namesection	{
	#USE 		namesection
    	ignorews 	1
	startAction 	{
	    troffRequest .BS ; set ::manstate(inBS) 1
	    sectionHeading NAME
	}
    }
    synopsis {
	#USE		synopsis-section
   	startAction 	{ sectionHeading SYNOPSIS }
	ignorews	1
    }
    keywords {
	#USE		kwseealso
    	ignorews	1
	startAction	{ sectionHeading KEYWORDS }
    }
    seealso {
	#USE		kwseealso
    	ignorews	1
	startAction	{ sectionHeading "SEE ALSO" }
    }
    section {
	ignorews	1
    	#USE		section
	startAction	do.VS
	endAction	do.VE
    }
}

lpd::linkset tmml2man section {
    subsection { #USE subsection }
    title {
    	diversion	title
	stringmap	troffarg
	postAction {
	    sectionHeading [translate::undivert title]
	}
    }
}

lpd::linkset tmml2man subsection {
    title {
    	diversion	title
	stringmap	troffarg
	postAction 	{ troffRequest .SS [translate::undivert title] }
    }
}

lpd::linkset tmml2man namesection {
    title	{ suffix {: } }
    name	{ #POST namesection-name2 }
    desc	{ prefix { \\- } }
}
lpd::linkset tmml2man namesection-name2	{
    name	{ prefix {, } }
    desc 	{ prefix { \\- } }
}
lpd::linkset tmml2man kwseealso	{ {keyword ref} { #POST kwseealso2 } }
lpd::linkset tmml2man kwseealso2 { {keyword ref} { prefix ", " } }

### Block elements:
#
lpd::linkset tmml2man #INITIAL {
    p {
    	startAction	{ beStart ; troffRequest .PP }
    	endAction	{ beEnd }
    }
    {example syntax} {
	outputProc	nofillOutput
	startAction 	{ beStart; troffRequest .CS }
	endAction	{ beEnd;   troffRequest .CE }
    }
}

# <syntax> and <example> elements inside "SYNOPSIS" section
# are handled differently:
#
lpd::linkset tmml2man synopsis-section {
    {example syntax} {
	outputProc	nofillOutput
	startAction 	{ troffRequest .nf }
	endAction	{ troffRequest .fi }
    }
}

lpd::linkset tmml2man #INITIAL {
    ul {
   	#USE		bulleted-list
	ignorews	1
	startAction 	{ beStart }
	endAction   	{ beEnd }
    }
    ol {
	#USE		numbered-list
	ignorews	1
    	startAction 	{ beStart; set tmml2man(olcounter) 1 }
	endAction 	{ beEnd; }
    }

    dl	{ startAction { beStart } endAction { beEnd } }
    dle { startAction { do.VS } endAction { do.VE }  }
    dt	{
	stringmap	troffarg
	outputProc	troffOutput
    	startAction 	{ troffRequest .TP }
	endAction	{ translate::flush }
    }
    dd { startAction { bcStart } endAction { bcEnd } }

}

lpd::linkset tmml2man numbered-list {
    li {
    	startAction	{ do.VS ; troffRequest .IP "\[$tmml2man(olcounter)\]"; bcStart }
	endAction	{ bcEnd ; do.VE }
	postAction	{ incr tmml2man(olcounter) }
    }
}

lpd::linkset tmml2man bulleted-list {
    li {
    	startAction	{ do.VS ; troffRequest .IP "\\(bu"; bcStart }
	endAction	{ bcEnd ; do.VE }
    }
}

#variable maxcols 4
#variable tabstops "4c 8c 12c"
variable maxcols 3
variable tabstops "5.5c 11c"

lpd::linkset tmml2man #INITIAL {
    sl {
    	#USE 		simple-list
	ignorews 	1
	startAction {
	    # %%% should use different tabstops based on #cols
	    beStart
	    troffRequest .nf
	    translate::writeln ".ta $tabstops"
	    translate::output {\fB}
	    if {   ![string is integer $tmml2man(@cols)]
	        || $tmml2man(@cols) > $maxcols
	    } {
	    	set tmml2man(@cols) $maxcols
	    }
	    set tmml2man(licounter) 0
	}
	endAction {
	    translate::output {\fP}
	    troffRequest .fi
	    beEnd
	}
    }
}
lpd::linkset tmml2man simple-list {
    li {
	startAction {
	    if {$tmml2man(licounter) % $tmml2man(@cols) == 0} {
		translate::output "\n"
	    } else {
		translate::output "\t"
	    }
	}
	postAction {
		incr tmml2man(licounter)
	}
    }
}

# Extended lists:
#
variable xlcols 3			;# %%% count these instead
variable xltabs [list 4c 8c 12c]
variable xlrow0 [list]
variable lmargin 0
variable rmargin 15			;# in cm

# tabstops <n> --
#	Return troff .ta specification for $n equal-width columns
#
proc tabstops {n} {
    variable lmargin; 
    variable rmargin;
    set k 10.0
    set w [expr {$k * 1.0 * ($rmargin-$lmargin)/$n}]
    set l [expr {$k * 1.0 * $lmargin}]
    set tabs [list];
    for {set i 1} {$i < $n} {incr i} {
	lappend tabs "[expr {round($lmargin + $i*$w) / $k}]c"
    }
    return $tabs
}

lpd::linkset tmml2man #INITIAL {
    xl	{ 
	ignorews 1
	#USE xl1
    	startAction { 
	    variable xltabs [tabstops 4]	; # %%%
	    beStart
	}
	endAction { beEnd } 
    }
}

lpd::linkset tmml2man xl0 {
    {xlh xle} { #POST xl1 } 
}
lpd::linkset tmml2man xl1 {
    xlh {
	ignorews 1
	stringmap troffarg
    	startAction {
	    variable xlheadings [list]
	}
	endAction {
	    troffRequest .sp 1
	    troffRequest .nf
	    set xltabs [tabstops [llength $xlheadings]]
	    translate::writeln ".ta [join $xltabs]"
	    translate::writeln [join $xlheadings "\t"]
	    #; translate::writeln "\01\01\01\01";
	}
    }

    xh { 
    	prefix {\\fB} suffix {\\fP}  font B 
	diversion xh
	endAction {
	    lappend xlheadings [translate::undivert xh]
	}
    }
    xle {
	ignorews 1
	stringmap troffarg
    	startAction {
	    variable xltabs
	    troffRequest .nf
	    translate::writeln ".ta [join $xltabs]"
	}
	endAction {
	    troffRequest .fi
	}
    }

    xt { suffix "\t" }

    desc {
	stringmap troff
    	startAction {
	    troffRequest .fi
	    troffRequest .RS 
	}
    	endAction {
	    troffRequest .RE 
	}
    }
}

### Phrase-level elements:
#
lpd::linkset tmml2man #INITIAL {
    {cmd opt method option 
     file syscmd widget fun variable package 
     type class term} {
    	prefix {\\fB} suffix {\\fP}
    }
    {i m emph}  {
    	font 		I
	prefix 		{\\fI}
	postAction	{ translate::output "\\f$tmml2man(font)" }
    }
    {b l samp command}  {
    	font 		B
	prefix 		{\\fB}
	postAction	{ translate::output "\\f$tmml2man(font)" }
    }
    {o} {
    	font	R
	prefix	{ \\fR?\\fP }
	suffix	{ \\fR?\\fP }
    }
    {url} {
    	diversion url
	endAction {
	    set url [translate::undivert url]
	    troffRequest .UR $url
	    translate::writeln "<URL: [string trim $url]>"
	    troffRequest .UE
	}
    }

    br		{ startAction { troffRequest .br } }
    ref		{ }
    new		{ startAction { do.VS } endAction { do.VE } }
}

### Tcl-specific structures:
#

# %%% Problem: can't generate ".AS" macro properly at the
# %%% start of an arglist, since we don't know what the longest
# %%% argument type/argument name is at this point...
# %%% "unsigned long" / "clientData" seems to work OK...

lpd::linkset tmml2man #INITIAL {
    arglist	{
    	#USE		arglist
	ignorews	1
	startAction {
	    troffRequest .AS "unsigned long" "clientData"
	}
    }
    optlist { #USE optlist  ignorews 1
    	startAction beStart endAction beEnd }
    commandlist { #USE commandlist  ignorews 1
    	startAction beStart endAction beEnd }
    optionlist 	{ #USE optionlist  ignorews 1
    	startAction { beStart } endAction { beEnd } }
}

lpd::linkset tmml2man arglist {
    argdef	{ ignorews 1  startAction { do.VS }  endAction { do.VE } }
    argtype	{ diversion argtype  stringmap troffarg }
    name	{ diversion argname  stringmap troffarg }
    argmode	{ diversion argmode  stringmap troffarg }
    desc {
    	startAction {
	    troffRequest .AP \
	    	[translate::undivert argtype] \
	    	[translate::undivert argname] \
	    	[translate::undivert argmode] \
		;
	    bcStart
	}
	endAction { bcEnd }
    }
}

lpd::linkset tmml2man optlist {
    optdef	{ ignorews 1 startAction { do.VS }  endAction { do.VE } }
    optname	{ diversion option stringmap troffarg }
    optarg	{ diversion option stringmap troffarg
    			prefix {  \\fI} suffix {\\fP} }
    desc	{
    	startAction {
	    troffRequest .IP "\\fB[translate::undivert option]\\fR"
	    bcStart
	}
	endAction { bcEnd }
    }
}

lpd::linkset tmml2man optionlist {
    optiondef	{ ignorews 1 startAction { do.VS }  endAction { do.VE } }
    name	{ diversion optname  stringmap troffarg }
    dbname	{ diversion dbname   stringmap troffarg }
    dbclass	{ diversion dbclass  stringmap troffarg }
    desc {
    	startAction {
	    troffRequest .OP \
	    	[translate::undivert optname] \
	    	[translate::undivert dbname] \
	    	[translate::undivert dbclass] \
		;
	    bcStart
	}
	endAction { bcEnd }
    }
}

lpd::linkset tmml2man commandlist {
    commanddef	{ ignorews 1 startAction { do.VS }  endAction { do.VE } }
    command {
	stringmap	troffarg
    	startAction 	{ troffRequest .TP }
	endAction	{ translate::output "\n"; translate::flush }
    }
    desc { startAction { bcStart } endAction { bcEnd }  }
}


### NYI:
#
lpd::linkset tmml2man #INITIAL-NYI {
    manual		{ }
    division		{ }
    subdoc		{ }
    extref		{ }
    new			{ }
}

######################################################################
#
# Main routine:
#

proc main {} {
    variable options
    if {[string length $options(lpd)]} {
    	uplevel #0 [list source $options(lpd)]
    }
    if {$options(debuglpd)} {
	lpd::configure tmml2man -debug 1
    }
    global argv
    if {[llength $argv] != 1} {
	puts stderr [cmdline::usage $::optlist]
	exit 1
    }
    set filename [lindex $argv 0]
    if {$options(output) == "-"} {
    	set output stdout
    } else {
    	set output [open $options(output) w]
    }
    translate::processFile tmml2man $filename $output
}

if {![string compare $::argv0 [info script]]} { main }

#*EOF*
