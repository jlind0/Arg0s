# Auto-Voice and No-Voice Management Script for Eggdrop
# This script will auto-voice users, track their IP/host, and manage "no voice" restrictions.

# File to store the no_voice_list
set no_voice_file "data/no_voice_list.txt"

# List to store IPs/hosts that are flagged as "do not voice"
set no_voice_list {}

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


# Channel to monitor (modify as needed)
set monitored_channel "#icons_of_vanity"

# Bind JOIN events to auto-voice users
bind join - * auto_voice_on_join

# Bind DEVOICE events to mark as "do not voice"
bind mode - * track_devoice

# Bind REVOICE events to allow auto-voice again
bind mode - * track_revoice

# Function to auto-voice users when they join
proc auto_voice_on_join {nick host hand chan} {
    global no_voice_list monitored_channel
    if {$chan ne $monitored_channel} {
        return
    }

    # Check if user is in the no_voice_list
    set user_ip_host [gethost $nick]
    if {[lsearch -exact $no_voice_list $user_ip_host] == -1} {
        # User is not in no_voice_list; auto-voice them
        putserv "MODE $chan +v $nick"
        putlog "Auto-voiced user $nick ($user_ip_host) in $chan."
    } else {
        putlog "Skipped auto-voicing $nick ($user_ip_host) because they are flagged as 'do not voice'."
    }
}

# Function to handle de-voice and add to no_voice_list
proc track_devoice {nick host hand chan modes args} {
    global no_voice_list monitored_channel
    if {$chan ne $monitored_channel} {
        return
    }

    # Check if mode is a de-voice (-v)
    if {[string match "-v*" $modes]} {
        foreach target $args {
            set user_ip_host [gethost $target]
            if {[lsearch -exact $no_voice_list $user_ip_host] == -1} {
                lappend no_voice_list $user_ip_host
                putlog "Added $target ($user_ip_host) to 'no voice' list."
            }
        }
    }
}

# Function to handle re-voice and remove from no_voice_list
proc track_revoice {nick host hand chan modes args} {
    global no_voice_list monitored_channel
    if {$chan ne $monitored_channel} {
        return
    }

    # Check if mode is a re-voice (+v)
    if {[string match "+v*" $modes]} {
        foreach target $args {
            set user_ip_host [gethost $target]
            if {[lsearch -exact $no_voice_list $user_ip_host] != -1} {
                set no_voice_list [lreplace $no_voice_list [lsearch -exact $no_voice_list $user_ip_host] [lsearch -exact $no_voice_list $user_ip_host]]
                putlog "Removed $target ($user_ip_host) from 'no voice' list."
            }
        }
    }
}

# Helper function to resolve IP/host of a user
proc gethost {nick} {
    # Check if the user exists in the userlist
    if {[onchan $nick] != ""} {
        # Use the 'onchan' command to fetch user's host/IP on the current channel
        set host [onchan $nick]
        if {$host ne ""} {
            return $host
        }
    }

    # If 'onchan' doesn't work or user is not found, try using Eggdrop's internal userlist
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