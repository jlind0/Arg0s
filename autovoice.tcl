# Auto-Voice and No-Voice Management Script for Eggdrop
# This script will handle multiple channels and use a single no_voice_list across them.

# File to store the no_voice_list
set no_voice_file "data/no_voice_list.txt"

# List to store IPs/hosts that are flagged as "do not voice"
set no_voice_list {}

# Channels to monitor (space-separated)
set monitored_channels "#icons_of_vanity #odyss3us #crusher"

# Function to save the no_voice_list to a file
proc save_no_voice_list {} {
    global no_voice_list no_voice_file

    # Open the file for writing
    set file [open $no_voice_file w]
    foreach entry $no_voice_list {
        puts $file $entry
    }
    close $file
    putlog "Saved no_voice_list to $no_voice_file."
}

# Function to load the no_voice_list from a file
proc load_no_voice_list {} {
    global no_voice_list no_voice_file

    # Check if the file exists
    if {[file exists $no_voice_file]} {
        set file [open $no_voice_file r]
        set no_voice_list [split [read $file] "\n"]
        close $file
        putlog "Loaded no_voice_list from $no_voice_file."
    } else {
        putlog "No no_voice_list file found. Starting with an empty list."
    }
}

# Call this function at startup to load the list
load_no_voice_list

# Call this function to save the list when the bot shuts down
bind evnt - shutdown save_no_voice_list

# Bind JOIN events to auto-voice users
bind join - * auto_voice_on_join

# Bind DEVOICE events to track "do not voice"
bind mode - * track_devoice

# Bind REVOICE events to remove from "do not voice"
bind mode - * track_revoice

# Function to check if a channel is monitored
proc is_monitored_channel {chan} {
    global monitored_channels
    return [expr {[lsearch -exact $monitored_channels $chan] != -1}]
}

# Function to auto-voice users when they join a monitored channel
proc auto_voice_on_join {nick host hand chan} {
    global no_voice_list

    if {![is_monitored_channel $chan]} {
        return
    }
    set user_ip_host [gethost $nick]
    
        # Check if user is in the no_voice_list
        
        if {[lsearch -exact $no_voice_list $user_ip_host] == -1} {
            # User is not in no_voice_list; auto-voice them
            utimer 30 [list putserv "MODE $chan +v $nick" ]
            putlog "Auto-voiced user $nick ($user_ip_host) in $chan."
        } else {
            putlog "Skipped auto-voicing $nick ($user_ip_host) in $chan because they are flagged as 'do not voice'."
        }
    
}

# Function to handle de-voice and add to no_voice_list
proc track_devoice {nick host hand chan modes args} {
    global no_voice_list monitored_channels

    if {![is_monitored_channel $chan]} {
        return
    }

    # Check if mode is a de-voice (-v)
    if {[string match "-v*" $modes]} {
        foreach target $args {
            set user_ip_host [gethost $target]
            if {[lsearch -exact $no_voice_list $user_ip_host] == -1} {
                # Add to no_voice_list
                lappend no_voice_list $user_ip_host
                putlog "Added $target ($user_ip_host) to 'no voice' list."

                # De-voice the user in all monitored channels
                foreach c $monitored_channels {
                    putserv "MODE $c -v $target"
                }
            }
        }
    }
}

# Function to handle re-voice and remove from no_voice_list
proc track_revoice {nick host hand chan modes args} {
    global no_voice_list

    if {![is_monitored_channel $chan]} {
        return
    }

    # Check if mode is a re-voice (+v)
    if {[string match "+v*" $modes]} {
        foreach target $args {
            set user_ip_host [gethost $target]
            set idx [lsearch -exact $no_voice_list $user_ip_host]
            if {$idx != -1} {
                set no_voice_list [lreplace $no_voice_list $idx $idx]
                putlog "Removed $target ($user_ip_host) from 'no voice' list."
            }
        }
    }
}

# Helper function to resolve IP/host of a user
proc gethost {nick} {
    # Check if the user exists in the userlist
    if {[onchan $nick] != ""} {
        # Use the 'onchan' command to fetch user's host/IP
        set host [onchan $nick]
        if {$host ne ""} {
            return $host
        }
    }

    # If 'onchan' doesn't work or user is not found, try Eggdrop's internal userlist
    set handle [matchattr $nick]
    if {$handle ne ""} {
        # Use 'hand2host' to retrieve the host/IP for a matched handle
        set host [hand2host $handle]
        if {$host ne ""} {
            return $host
        }
    }

    # If no match is found, return a placeholder indicating an unknown host
    return "unknown-host"
}
