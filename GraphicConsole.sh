#!/bin/bash

# All the constructions like:
# if [ -z "$VARIABLE"]; then
#   SOMETHING
# fi
# Are to detect if input is empty
# and protects the programm from errors

function HelpWindow() {
    local HELP="Options:
Create new file             -> Enter a name for a file and then select where you want to put it
Create new directory        -> Enter a name for a directory and then select where you want to put it
Rename directory            -> Choose a directory to rename
Find file                   -> Enter name of the files you are searching for. The results will show their directory and peorperties
Work on file                -> Select a file and do on it following operations:
                                1) Set file permissions  -> Set permissions for owner, group and others
                                2) Edit content          -> View the content of the file and be able to edit it
                                3) Move File             -> Move file to different directory
                                4) Rename                -> Change name of the file
                                5) Back                  -> Go back to main menu
Move                        -> Move directory or file to different directory
Left memory                 -> Show left memory
Enter Command               -> Enter a custom command. The results of the command will be shown in cmd instead of zenity.
Current processes           -> View current processes
Run a script                -> Select a script and run it
Create directory shortcut   -> Select a directory and store it in the shortcuts
Set directory               -> Select a directory from the stored list. Now you will start from it in the next options
Create file shortcut        -> Find a file and add it to shortcuts list
Saved files list            -> Display list of stored files and select one to start working on it
Browse                      -> Browse files on your computer
Verbose                     -> See information about this script
Help                        -> Display this window
Quit                        -> End the script
"
    echo "$HELP" > /tmp/help.txt
    zenity --text-info --title="Help" --filename=/tmp/help.txt --width=1100 --height=700 --font="DejaVu Sans Mono 10"
    rm /tmp/help.txt
}

function VersionWindow() {
    local VERSION="Author: Adrian Belczak
Version: 1.0
License: MIT"

    zenity --info --text="$VERSION" --title="Version" --height="100" --width="200"
}

function FileList() {
    # Display possible file shortcuts
    local SELECTED=$(zenity --list --column="Directories" "${FILE_LIST[@]}" --width="600" --height="500")

    if [ -z "$SELECTED" ]; then
        return
    fi

    # Enter file editing mode
    FileEditMode $SELECTED
}

function AddFileShortcut() {
    local NEW_FILE=$(zenity --file-selection --title="Select file to add to shortcuts" --filename=$CURRENT_DIR)

    if [ -z $NEW_FILE ]; then
        return
    fi

    # Add chosen file to list
    FILE_LIST+=("$NEW_FILE")
}

function BrowseFiles() {
    # Just for browsing -> nothing is changed here
    zenity --file-selection --title="Browse" --width="750" --height="750" --filename=$CURRENT_DIR
}

function AddDirShortcut() {
    # Display all saved file shortcuts
    local NEW_SHORTCUT=$(zenity --file-selection --directory --width="300" --height="100" --title="Set Shortcut")
    if [ -z $NEW_SHORTCUT ]; then
        return
    fi

    SAVED_DIR+=("$NEW_SHORTCUT") 
}

function SetCurrentDir() {
    # Display all saved directories
    local SELECTED=$(zenity --list --column="Directories" "${SAVED_DIR[@]}" --width="600" --height="500")

    if [ -z "$SELECTED" ]; then
        return
    fi

    CURRENT_DIR=$SELECTED
}

function RunScript() {

    local SCRIPT=$(zenity --file-selection --title="Select script to run" --file-filter="*.sh" --filename=$CURRENT_DIR)

    if [[ -z $SCRIPT ]]; then
        return
    fi

    # Make the script executable
    chmod +x $SCRIPT
    
    # Run script
    "$SCRIPT"
}

function RenameFile() {

    # If argument is passed, get the file from it
    if [ ! -n $1 ]; then
        local FILE=$(zenity --file-selection --title="Select file to rename" --filename=$CURRENT_DIR)
    else
        local FILE=$1
    fi

    if [[ -z $FILE ]]; then
        return
    fi

    local NEW_NAME=$(zenity --entry --title="Rename file" --text="Enter a new name for $FILE")

    if [[ -z $NEW_NAME ]]; then
        return
    fi

    if [ "$NEW_NAME" = "$(basename $FILE)" ]; then
        zenity --error --text="New name is the same as old one"
        return
    fi

    local NEW_DIR=$(dirname $FILE)/$NEW_NAME
    mv $FILE $NEW_DIR

    # Check if this file was on a saved list
    for ((i = 0; i < ${#FILE_LIST[@]}; i++)); do
        if [ "${FILE_LIST[$i]}" = "$FILE" ]; then
            FILE_LIST[$i]="$NEW_DIR"
        fi
    done

    zenity --info --text="$FILE renamed to $NEW_DIR"
    if [ -n $2 ]; then
        # Change the passed argument
        eval "$2=\$NEW_DIR"
    fi
}

function RenameDir() {

    local FILE=$(zenity --file-selection --directory --title="Select directory to rename" --filename=$CURRENT_DIR)

    if [[ -z $FILE ]]; then
        return
    fi

    local NEW_NAME=$(zenity --entry --title="Rename file" --text="Enter a new name for $FILE")

    if [[ -z $NEW_NAME ]]; then
        return
    fi

    # Check if name is the same
    if [ "$NEW_NAME" = "$(basename $FILE)" ]; then
        zenity --error --text="New name is the same as old one"
        return
    fi

    local NEW_DIR=$(dirname $FILE)/$NEW_NAME
    mv $FILE $NEW_DIR
    CURRENT_DIR="$NEW_DIR"

    # Check if that directory was previously on the saved list
    for ((i = 0; i < ${#SAVED_DIR[@]}; i++)); do
        if [ "${SAVED_DIR[$i]}" = "$FILE" ]; then
            SAVED_DIR[$i]="$NEW_DIR"
        fi
    done

    zenity --info --text="$FILE renamed to $NEW_DIR"
}


function DisplayProcesses() {
    # Store processes in a file
    ps -eo pid,pcpu,comm --sort=-pcpu > /tmp/processes.txt

    # display that file
    zenity --text-info --title="List of Processes" --filename=/tmp/processes.txt --width=800 --height=600 --font="DejaVu Sans Mono 12"

    # Remove the temporary file
    rm /tmp/processes.txt
}

function EnterCommand() {
    local COMMAND=$(zenity --entry --width="100" --title="Command" --text="Enter command:")
    eval "$COMMAND" 2>/dev/null
}

function ShowLeftMemory() {
    # Get memory in bytes
    local MEMORY_BYTES=$(free -b | grep Mem | awk '{print $7}')

    # Transfer bytes to gigabytes
    local MEMORY_GB=$(echo "scale=2; $MEMORY_BYTES / (1024^3)" | bc)
    zenity --info --text="Free memory: $MEMORY_GB GB" --width="300"
}

function Move() {

    # Choose to move file or directory
    local TYPE=$(zenity --list --title="File/Directory to move" --column="Type" \
        "File" \
        "Directory")

    if [ -z $TYPE ]; then
        return
    fi

    case $TYPE in
        "File")
            local DIR=$(zenity --file-selection --title="Choose file to move" --filename=$CURRENT_DIR)
            if [ -z $DIR ]; then
                return
            fi
            local DESTINATION=$(zenity --file-selection --directory --title="Move to:" --filename=$CURRENT_DIR)
        ;;

        "Directory")
            local DIR=$(zenity --file-selection --directory --title="Choose directory to move" --filename=$CURRENT_DIR)
            if [ -z $DIR ]; then
                return
            fi
            local DESTINATION=$(zenity --file-selection --directory --title="Move to:" --filename=$CURRENT_DIR)
        ;;
    esac

    if [ -z $DESTINATION ]; then
        return
    fi

    mv $DIR $DESTINATION
    zenity --info --text="$DIR has been successfully moved to $DESTINATION"
}

function MoveFile() {

    local DIR=$1
    local DESTINATION=$(zenity --file-selection --directory --title="Move to:" --filename=$CURRENT_DIR)

    # check if nothing has vbeen selected
    if [ -z $DESTINATION ]; then
        return
    fi

    if [ "$DIR" = "$DESTINATION/$(basename "$DIR")" ]; then
        zenity --error --text="Cannot move file to the same location."
        return
    fi

    mv $DIR $DESTINATION
    zenity --info --text="File $DIR has been successfully moved to $DESTINATION"

    local NEW_DIR="$DESTINATION/$(basename "$DIR")"
    eval "$2=\$NEW_DIR"
}


function CreateDir() {

    # Ask for name
    local DIR_NAME=$(zenity --entry --title="New Directory" --text="Enter directory name:")
    if [ ! -z $DIR_NAME ]; then
        # Select location for new folder
        local FILEPATH=$(zenity --file-selection --directory --title="Select location" --filename=$CURRENT_DIR)
        if [[ ! -z $FILEPATH ]]; then
            # If everything is set -> make folder
            mkdir $FILEPATH/$DIR_NAME
            zenity --info --text="Directory $DIR_NAME has been successfully created in $FILEPATH"
        fi
    fi
}

function EditFile() {

    # Check if we are in EditFileMode
    if [ -z "$1" ]; then
        local FILEPATH=$(zenity --file-selection --title="Choose File" --filename=$CURRENT_DIR)
    else
        local FILEPATH=$1
    fi


    if [ ! -z "$FILEPATH" ]; then
        FILE_EXT="${FILEPATH##*.}"

        # Check if file is editable
        FILE_EXT="${FILEPATH##*.}"
        NON_EDITABLE_EXTENSIONS=("jpg" "png" "gif")

        if [[ "${NON_EDITABLE_EXTENSIONS[@]}" =~ "$FILE_EXT" ]]; then
            zenity --info --title="Error" --text="File not editable"
            return
        fi

        if [ ! -f "$FILEPATH" ] || [ ! -r "$FILEPATH" ] || [ ! -w "$FILEPATH" ]; then
            zenity --info --title="Error" --text="File not editable"
            return
        fi

        # Create a zenity window with text from the file
        # After user confirms -> store it in NEWTEXT
        local NEWTEXT=$(cat $FILEPATH | zenity --text-info --title="Edit File" --width=800 --height=600 --editable --font="DejaVu Sans Mono 12")
        if [ ! -z "$NEWTEXT" ]; then
            # Copy edited text to the real file
            echo -e "$NEWTEXT" > "$FILEPATH"
        fi
    fi
}

function SetPermissions() {

    # If we are currently working with a file, user doesnt have to choose
     if [ -z $1 ]; then
        local FILEPATH=$(zenity --file-selection --title="Choose File" --filename=$CURRENT_DIR)
    else
        local FILEPATH=$1
    fi
    
    if [[ ! -z "$FILEPATH" ]]; then

        # Create menu to choose permissions
        local PERMISSIONS=$(zenity --forms --title="Set Permissions" --text="Choose permissions:" \
        --add-combo="Owner" \
        --combo-values="rwx|r-x|rw-|r--|-wx|-x-|--w|---" \
        --add-combo="Group" \
        --combo-values="rwx|r-x|rw-|r--|-wx|-x-|--w|---" \
        --add-combo="Others" \
        --combo-values="rwx|r-x|rw-|r--|-wx|-x-|--w|---" \
        --separator="|")


        local OWNER=$(echo "$PERMISSIONS" | awk -F'|' '{print $1}')
        local GROUP=$(echo "$PERMISSIONS" | awk -F'|' '{print $2}')
        local OTHERS=$(echo "$PERMISSIONS" | awk -F'|' '{print $3}')
        PERMISSIONS="u=$OWNER,g=$GROUP,o=$OTHERS"

        chmod $PERMISSIONS $FILEPATH
        zenity --info --text="Permissions of $FILEPATH have been changed to $OWNER$GROUP$OTHERS"
    fi
}

function FindFile() {

    local FILENAME=$(zenity --entry --title="File Name" --text="enter file name:")

    # Store found files
    local FOUND=$(find / -type f -name $FILENAME 2>/dev/null)
    local OUTPUT
    local FILE_PROPERTIES
    for FILE in $FOUND; do
        FILE_PROPERTIES=$(ls -l "$FILE")
        OUTPUT+="$FILE:
        $FILE_PROPERTIES
"
    done

    if [[ -z $FOUND ]]; then
        zenity --info --title="No Entries" --text="No file named $FILENAME"
    else
        zenity --text-info --title="Entries" --width="1000" --height="700" --filename=<(echo "$OUTPUT") --font="DejaVu Sans Mono 10"
    fi
}

function CreateFile() {

    # Create file name
    local FILENAME=$(zenity --entry --title="New File" --text="Enter file name:")

    # Check if name was entered
    if [[ ! -z "$FILENAME" ]]; then
        local FILEPATH=$(zenity --file-selection --directory --title="Select location" --filename=$CURRENT_DIR)

        # Check if path was chosen
        if [[ ! -z $FILEPATH ]]; then

            # Create file
            touch "$FILEPATH/$FILENAME"
            zenity --info --text="File $FILENAME has been successfully created in $FILEPATH"
        fi
    fi
}

function FileEditMode() {

    # Set file to work with
    if [ -z $1 ]; then
        local CUR_FILE=$(zenity --file-selection --title="Pick file to edit" --filename=$CURRENT_DIR)
    else
        local CUR_FILE=$1
    fi

    if [ -z $CUR_FILE ]; then
        CURRENT_DIR="/"   
        return
    fi

    CURRENT_DIR=$CUR_FILE

    while true
    do
        local OPTION=$(zenity --list --title="Graphic Console" --width="400" --height="500" --column="Editing $CUR_FILE" \
            "Set file permissions" \
            "Edit content" \
            "Move File" \
            "Rename" \
            "Back")

        if [ -z "$OPTION" ]; then
            CURRENT_DIR="/"
            return
        fi

        case $OPTION in

            "Set file permissions")
                SetPermissions $CUR_FILE
            ;;

            "Edit content")
                EditFile $CUR_FILE
            ;;

            "Move File")
                MoveFile $CUR_FILE "CUR_FILE"
            ;;

            "Rename")
                RenameFile $CUR_FILE "CUR_FILE"
            ;;

            "Back")
                CURRENT_DIR="/"
                return
            ;;

            *)
                CURRENT_DIR="/"
                return
            ;;

        esac
    done
}


function ShowMenu() {

    local OPTION=$(zenity --list --title="Graphic Console" --width="400" --height="600" --column="Options" \
    "Create new file" \
    "Create new directory" \
    "Rename directory" \
    "Find file" \
    "Work on a file" \
    "Move" \
    "Left memory" \
    "Enter command" \
    "Current processes" \
    "Run a script" \
    "Create directory shortcut" \
    "Set directory" \
    "Create file shortcut" \
    "Saved files list" \
    "Browse" \
    "Version" \
    "Help" \
    "Quit")

    case $OPTION in

        "Create new file")
            CreateFile
        ;;

        "Create new directory")
            CreateDir
        ;;

        "Rename directory")
            RenameDir
        ;;

        "Find file")
            FindFile
        ;;

        "Work on a file")
            FileEditMode
            CURRENT_DIR="/"
        ;;

        "Move")
            Move
        ;;

        "Left memory")
            ShowLeftMemory
        ;;

        "Enter command")
            EnterCommand
        ;;

        "Current processes")
            DisplayProcesses
        ;;

        "Run a script")
            RunScript
        ;;

        "Create directory shortcut")
            AddDirShortcut
        ;;

        "Set directory")
            SetCurrentDir
            cd "$CURRENT_DIR"
        ;;

        "Create file shortcut")
            AddFileShortcut
        ;;

        "Saved files list")
            FileList
        ;;

        "Browse")
            BrowseFiles
        ;;

        "Version")
            VersionWindow
        ;;

        "Help")
            HelpWindow
        ;;

        "Quit")
            EXIT=true
        ;; 

        *)
            EXIT=true
        ;;
    esac
}


EXIT=false
CURRENT_DIR="/"
SAVED_DIR=(
    "/var/log"
    "/proc"
    "/sys"
    "/dev"
    "/usr/bin"
    "/usr/sbin"
    "/etc/network/interfaces"
)
FILE_LIST=(
    "/etc/passwd"
    "/etc/group"
    "/etc/fstab"
    "/etc/hosts"
)

# programm loop
while [ $EXIT != true ]
do
    ShowMenu  
done