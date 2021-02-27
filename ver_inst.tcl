#!/usr/bin/tclsh
#-------------------------------------------------------------------------------
# Created by		: Telan Tan
# Filename		: ver_inst.tcl
# Author		: Telan Tan , telantan@gmail.com
# Created On		: 2013-11-05 22:38
# Version		: v1.0
# Description		: verilog instance generation
#-------------------------------------------------------------------------------
# Revision History :
# 1.0 2013.11.6
#     initial release 
# 2.0 2013.11.8
#     1. add -o ofile_name.v options for file generation on disk
#     2. add parameter/port width auto match capability
# 3.0 2021.2.26
#     1.public release

proc vinst { args } {

#1. extract arguments, open source file
set para_inst 0
set temp ""
set p_arg ""
set of_arg ""

set argnum [llength $args]

if {$argnum == 1} {
    set file_name [lindex $args 0]
    if { [string equal $file_name -h] } {
        puts "This is a simple verilog instantiation template generation script by Telan."
        puts "syntax format : vinst verilog_file_name.v options."
        puts "example 1: vinst a.v "
        puts "           Generate only ports connection, no parameter"
        puts "example 2: vinst a.v -p0"
        puts "           Generate both ports and parameter connection"
        puts "           Parameter connections style same as source file, .LEN (3)"
        puts "example 3: vinst a.v -p1"
        puts "           Generate both ports and parameter connection"
        puts "           Parameter name and value are totally same, .LEN(LEN) "
        puts "example 4: vinst a.v -o ofile_name.v"
        puts "           Besides the console, the generated instance is also written into a file on disk "

        return
    }
} elseif {$argnum >= 2} {
    set file_name [lindex $args 0]
    #extract p0 p1 argument
    regexp {[ |\t]+(-p[0-1])} $args temp p_arg
    #extract -o ofile.v argument
    regexp {[ |\t]+-[oO][ |\t]+([a-z_A-Z0-9.]+)} $args temp  of_arg
    
    if { $p_arg != "" } {
        if { [string equal $p_arg -p0] } {
            set para_inst 1
        } elseif { [string equal $p_arg -p1] } {
            set para_inst 2
        } else {
            puts "Illegal second arguments, should only be -p0 or -p1"
            return
        }
    }

} else  {
    #puts $arglist
    puts "Fucntion: Make an instance of verilog module!"
    puts "Usage   : ver_inst.tcl \[verilog_file_name\] null|-p0|-p1"
    return
}

if { [catch {open "$file_name" r} ifhandle] } {
    puts "Cannot open $file_name for read!"
    return
}


set port_list ""
set pa_list ""
set para_list [list]
set info_list [list]
set done 0
set block_comment_start 0
set module_found 0
set para_found 0

#2. read through source file, first to reach module part dirtecly
while { !$module_found } {
    if { [eof $ifhandle] } {
        puts "no module found!"
	return
    }	
    set line [gets $ifhandle]
    set module_found [regexp {^( +|\t+)*module} $line]
    if { !$module_found } {
       continue
    } else {
       break
    }

}

# 3.processing the main body of module, 
# consider all possible syntax sytle 1995/2001
# module xxx #(paramter xxx = vvvv) ( 
#   input|output wire|reg [11:0] pname,xxx);
while {!$done} {
    if {!$module_found }  {
        set line [gets $ifhandle]
        #puts $line
    } else {
        set module_found 0
    }

    #remove left space tab 
    set line [string trimleft $line]
       
    while {$line!=""} {
	#puts $line
	#check the */ end of block comment
        if {$block_comment_start} {
            if {[regexp {\*/} $line]} {
                set block_comment_start 0
                set line [string replace $line 0 [string first */ $line]+1]
                continue
            } else {
	        break
            }
         } elseif { $para_found } {
	    #remove // comment
            if {[regexp {//} $line]} {
                set line [string replace $line [string first // $line] end]
		continue
            }
            # detect /* block comment start point, keep the part before comment and jump the block
            if {[regexp {/\*} $line]} {
                set block_comment_start 1
		#extract valid info before /*
                set valid_part [string range $line 0 [string first /* $line]-1 ]
		set para_list [concat $para_list $valid_part]
                #still keep info after /*, maybe */ is still there
                set line [string range $line [string first /* $line]+2 end]
                continue
            }
	    if { [regexp {\)} $line] } {
	        set temp [string first ( $line]
		if { [regexp {.*\(+.*\)+} $line] } {
	            set para_list [concat $para_list $line]
	            break
		}
	        set para_found 0
                set valid_part [string range $line 0 [string first ) $line] ]
	        set para_list [concat $para_list $valid_part]
                set line [string replace $line 0 [string first ) $line]]
                continue
            } else {
	        set para_list [concat $para_list $line]
	        break
	    }	
	 } else {
	    #remove // comment
            if {[regexp {//} $line]} {
                set line [string replace $line [string first // $line] end]
		continue
            }
            # detect /* block comment start point, keep the part before comment and jump the block
            if {[regexp {/\*} $line]} {
                set block_comment_start 1
		#extract valid info before /*
                set valid_part [string range $line 0 [string first /* $line]-1 ]
		set info_list [concat $info_list $valid_part]
                #still keep info after /*, maybe */ is still there
                set line [string range $line [string first /* $line]+2 end]
                continue
            }
	    # `include `define
            if {[regexp {^( +|\t+)*`} $line]} {
		break
            }
            
	    # detect parameter list
            set line [string trimright $line]
	    # same line with module , module top #
	    # or two lines, one is module top , another is #
            if { [regexp {module[ |\t]+([a-z_A-Z0-9]+)[ |\t]*#} $line] } {
	       set para_found 1
	       #keep the part before #
               set valid_part [string range $line 0 [string first # $line]-1 ]
	       set info_list [concat $info_list $valid_part]
               #still keep info after #, maybe ) is still there
               set line [string range $line [string first # $line]+1 end]
	       set para_list [concat $para_list $line]
               continue
	        
            } elseif { [regexp {^[ |\t]*#} $line] } {
	       set para_found 1
               #keep info after #, maybe ) is still there
               set line [string range $line [string first # $line]+1 end]
	       #set para_list [concat $para_list $line]
               continue

	    }

            set temp_ptr [string first ";" $line]
            if { $temp_ptr > 0} {
                set line [string range $line 0 $temp_ptr]
                set done 1
            }
	    set info_list [concat $info_list $line]
            break

	 }
    }
}



#3. analyze the module and ports info,
#  extract module and port list
set module_name ""
set info_list [string trimleft $info_list]
regexp {module[ |\t]+([a-z_A-Z0-9]+)[ |\t]*\((.*)\)} $info_list temp module_name port_list
#unset info_list
#unset temp
set port_list [split $port_list ",;"]

#extract parameter list
set para_list [string trimleft $para_list]
regexp {\((.*)\)} $para_list temp pa_list
set pa_list [ split $pa_list ,]

#extract verilog 1995 parameter format
set done 0
while {!$done} {
    set line [gets $ifhandle]
    #puts $line
    if { [eof $ifhandle] || [regexp {^[ |\t]*(endmodule*)+} $line ] } {
        set done 1
        break
    }
    #remove left space tab 
    set line [string trimleft $line]
    if { [regexp {^[ |\t]*(parameter.*)+([,;])} $line m s1 s2] } {
        set pa_list [concat $pa_list [list $s1] ]
        #puts $pa_list
    }   
}
#puts $pa_list

#4. start instantition
set m1 ""
set m2 ""
set m3 ""
set ports ""
set port ""
set para_item_list ""
set paras ""
set para ""
set values ""
set para_max_width 0
set para_value_max_width 0
set port_max_width 0
set port_w_max 0
array set para_items ""
array set para_value_items ""
array set port_items ""
array set port_declar_items ""
array set port_dir_items ""
array set port_width ""


if { $of_arg !="" } {
   set ofile_id [open $of_arg a+]
   #puts $of_arg
}

#4.1 port inst processing 
set str ""


#get the max width of ports, meanwhile packed all ports into array
for {set i 0} {$i < [llength $port_list]} {incr i} {
    #all possible format , input|output wire|reg [13:0] portname,
    set temp [lindex $port_list $i]
    
    #puts $temp
    #remove (*KEEP=TURE*) input clk,
    regexp {(^[ |\t]*\(\*.*\*\))(.*)} $temp m s1 temp
    #set temp [string trim $temp]
    #output a = 1 ,  = 1 was remove
    set equal_idx [ string last = $temp]
    if { $equal_idx > 0 } {
        #puts $equal_idx
        puts $temp
        set temp [ string range $temp 0 [expr $equal_idx - 1 ] ]
        #puts $temp
    }
    #puts $temp
    #extract 1st dimension port width
    if { [ regexp {.*\[[ |\t]*([0-9]+)[ |\t]*:([ |\t]*[0-9]+[ |\t]*\])(.*) } $temp m port_w s2 s3 ] } {
        #puts $port_w
        #puts $temp 
        #puts $s2 
        #puts $s3
    } else {
        set port_w 0
        #puts 0
    }

    

    set temp [string trim $temp]
    #puts $temp
    #extract direction
    if { [ regexp {^input.* } $temp ] } {
      #puts $temp
      set port_dir_items($i) i
    } else {
      set port_dir_items($i) o
    }

    set ports [split $temp] 
    set port [lindex $ports end]
    #puts $port
    set port [string trim $port]
    #remove [15:0]port_name, remove 1st port dimension
    regexp {(\[.*\])([a-z_A-Z0-9]+)} $port m s1 port 
    #puts $port
    set port_declar_items($i) $port

    #remove [15:0] a[0:3], remove port 2nd dimension
    regexp {([a-z_A-Z0-9]+)(\[.*)} $port m port s1 
    #puts $port
    #puts $s1
    #input dq_i = 1'b1 , remove = 1'b1
    #regexp {([a-z_A-Z0-9]+)[ |\t]*(=.*)*} $port ports temp1 port temp
    set port_items($i) $port
    set port_width($i) $port_w
    
    #get the max width of ports
    set temp [string length $port]
    if { $temp > $port_max_width } {
        set port_max_width  $temp
    } 
    
    if { $port_w > $port_w_max } {
        set port_w_max  $port_w
    }
}
set port_d_width   [expr $port_max_width + 4]
set port_max_width [expr $port_max_width + 2]

set len [expr {[llength $port_list] - 1}]
for {set i 0} {$i < [llength $port_list]} {incr i} {
    set port $port_declar_items($i)
    set port_w $port_width($i)

    if { $port_w_max < 10 } {
        if { $port_w == 0 } {
            set str [ format "wire      %-[expr $port_d_width]s;" $port ]
        } else {
            set str [ format "wire\[%d:0\] %-[expr $port_d_width]s;" $port_w $port ]
        }
    } elseif { $port_w_max < 100 } {
        if { $port_w == 0 } {
            set str [ format "wire       %-[expr $port_d_width]s;" $port ]
        } else {
            set str [ format "wire\[%2d:0\] %-[expr $port_d_width]s;" $port_w $port ]
        }
    }  elseif { $port_w_max < 1000 } {
        if { $port_w == 0 } {
            set str [ format "wire        %-[expr $port_d_width]s;" $port ]
        } else {
            set str [ format "wire\[%3d:0\] %-[expr $port_d_width]s;" $port_w $port ]
        }
    }   elseif { $port_w_max < 10000 } {
        if { $port_w == 0 } {
            set str [ format "wire         %-[expr $port_d_width]s;" $port ]
        } else {
            set str [ format "wire\[%4d:0\] %-[expr $port_d_width]s;" $port_w $port ]
        }
    }

    puts $str
    if { $of_arg !="" } {
        puts $ofile_id $str
    } 
}

puts "\n"

# 4.2 parameter inst processing
set len [expr {[llength $pa_list] -1 }]
set inst_name [string toupper U_$module_name]
if { $para_inst && $len >= 0 } {
    puts "$module_name #\("

    if { $of_arg !="" } {
        puts $ofile_id "$module_name #\("
    }

    for {set i 0} {$i < [llength $pa_list]} {incr i} {
        set temp [lindex $pa_list $i]
        set temp [string trim $temp]
        #puts $temp
	# divied into 2 parts , paras = values
	set valid_part $temp
        set temp [string first = $valid_part]
	set paras [string range $valid_part 0 [expr $temp - 1]]
	set values  [string range $valid_part [expr $temp + 1] end]
        #remove // /* comments
        if { [string first / $values ] > 0} {
            #puts $values
            set values [ string range $values 0 [ string first / $values ]-1 ]
        }
        #regexp {(.*)(//.*)} $values  m values s2
        #puts $s2
        set values [string trim $values]
	set para_value_items($i) $values

	# consider possible parameter sytle, parameter interger|[10:0] LEN = 100
	# only the end of the leftside LEN is valid
	set paras [string trim $paras]
	set para_item_list [split $paras]
        set para [lindex $para_item_list end]
        set para_items($i) $para

	#get the max width of parameter and values
	set temp [string length $para]
	if { $temp > $para_max_width } {
	    set para_max_width  $temp
	} 

	set temp [string length $values]
	if { $temp > $para_value_max_width } {
	    set para_value_max_width  $temp
	} 
        #puts $para_max_width
	#puts $para_value_max_width
     }
    set para_max_width [expr $para_max_width + 2]
    set para_value_max_width [expr $para_value_max_width + 2]

    for {set i 0} {$i < [llength $pa_list]} {incr i} {
        set para $para_items($i)
	set values $para_value_items($i)

	if { $para !="" } {
	    if {$i != $len } {	
	        if {$para_inst == 1} { 
                    set str [ format "    .%-[expr $para_max_width ]s( %-[expr $para_value_max_width ]s)," $para $values ]
		} else {
                    set str [ format "    .%-[expr $para_max_width ]s( %-[expr $para_max_width ]s)," $para $para ]
		}
		puts $str
		if { $of_arg !="" } {
		   puts $ofile_id $str
		}   
            } else {
	        if {$para_inst == 1} { 
                    set str [ format "    .%-[expr $para_max_width ]s( %-[expr $para_value_max_width ]s) )" $para $values ]
		} else {
                    set str [ format "    .%-[expr $para_max_width ]s( %-[expr $para_max_width ]s) )" $para $para ]
		}
		puts $str
		puts "    $inst_name \("
		if { $of_arg !="" } {
		   puts $ofile_id $str
                   puts $ofile_id "    $inst_name \("
		} 
	    }
	}
    }
} else {
    puts "$module_name $inst_name\("
    if { $of_arg !="" } {
        puts $ofile_id "$module_name $inst_name\("
    }
    
}


set len [expr {[llength $port_list] - 1}]
for {set i 0} {$i < [llength $port_list]} {incr i} {
    set port $port_items($i)
    set port_dir $port_dir_items($i)
    if { $i != $len } {
        set str [ format "    .%-[expr $port_max_width]s( %-[expr $port_max_width]s), //%s" $port $port $port_dir ]
	puts $str
	if { $of_arg !="" } {
            puts $ofile_id $str
	} 
    } else {
        set str [ format "    .%-[expr $port_max_width]s( %-[expr $port_max_width]s)  //%s" $port $port $port_dir]
	puts $str
        puts "\);"
	if { $of_arg !="" } {
            puts $ofile_id $str
            puts $ofile_id "\);"
	} 	
    }
}

if { $of_arg !="" } {
    close $ofile_id
}

}
