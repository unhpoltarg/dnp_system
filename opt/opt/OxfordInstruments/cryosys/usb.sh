#!/bin/sh

################################################################################
# usb.sh
#
# USB auto mount/unmount script.
#
# SVN Keywords
# $HeadURL:  $
# $Author:  $
# $Revision:  $
# $Date:  $
#
# Launched by mdev on USB mass storage device insertion or removal, this script
# mounts and unmounts the device into/out of the filing system.
#
# Notes:
# - mdev kicks off several of these at pretty much the same time, so we use a
#   flag-file-based mutex to ensure that only one instance is trying to do
#   anything actually significant at any given time.
# - We've had issues due to some filing system types needing specific mount
#   options in order to enable what most would see as the essential feature
#   of case preservation. The proper way to address this would probably be
#   to interrogate the media to determine its type prior to mount, and then
#   supply appropriate options to mount. But for the time being we're just
#   trying each set of options in turn (on the basis that mount fails if it's
#   given otions inappropriate for the media type), and then using mount with
#   no options as the ultimate fallback. The associated risk that occasionally
#   we'll mount a FS without case preservation is currently regarded as
#   acceptable.
#
# Copyright 2012 - Oxford Instruments
# This material is protected by copyright law. It is unlawful to copy it.
#
# This document contains confidential information. It is not to be disclosed or
# used except in accordance with applicable contracts or agreements. This
# document must be rendered illegible when being discarded.
#
################################################################################

# Exit on error.
set -e

# Log levels:
LL_OUTCOME=0
LL_PROGRESS=1
LL_TRACE=2

LOG_LEVEL=$LL_PROGRESS

USB_MPOINT=/mnt/usb
OUTPUT=/var/log/messages
USB_DEV=/opt/OxfordInstruments/cryosys/usbdev
EXEC_MUTEX_FILE=/tmp/usbExecMutexFile

################################################################################
# Function Definitions
################################################################################

fnLog()
# $1 - Log level of message
# $2 - Text to be logged.
################################################################################
{
    if [ $1 -le $LOG_LEVEL ]; then
        echo "usb.sh [$SEQNUM]: $2" >> "$OUTPUT"
    fi
}

fnDumpEnv()
# Dumps all the env vars given to us by mdev.
################################################################################
{
    fnLog $LL_TRACE "ACTION:        $ACTION"
    fnLog $LL_TRACE "SEQNUM:        $SEQNUM"
    fnLog $LL_TRACE "MAJOR:         $MAJOR"
    fnLog $LL_TRACE "MDEV:          $MDEV"
    fnLog $LL_TRACE "DEVPATH:       $DEVPATH"
    fnLog $LL_TRACE "SUBSYSTEM:     $SUBSYSTEM"
    fnLog $LL_TRACE "MINOR:         $MINOR"
    fnLog $LL_TRACE "PHYSDEVPATH:   $PHYSDEVPATH"
    fnLog $LL_TRACE "PHYSDEVDRIVER: $PHYSDEVDRIVER"
    fnLog $LL_TRACE "PHYSDEVBUS:    $PHYSDEVBUS"
    fnLog $LL_TRACE "PWD:           $PWD"
}

fnWaitForAndAcquireExecMutex()
# The mutex is actually a flag file.
################################################################################
{
    fnLog $LL_PROGRESS "Waiting to run."
    local _MUTEX_OWNED_BY_ME="n"

    while [ "$_MUTEX_OWNED_BY_ME" != "y" ]; do
        while [ -f "$EXEC_MUTEX_FILE" ]; do
            fnLog $LL_TRACE "."
            sleep 1s
        done
        echo $SEQNUM > "$EXEC_MUTEX_FILE"
        # The multiple instances of this script are launched sufficiently
        # coincidentally for the above not to be enough - all three instances
        # always see no flag file when they first look.
        # So the mutex owner is the one that sees its own SeqNum in the flag
        # file when it looks at the contents 1 second later.
        sleep 1s
        local _FILE_CONTENT=`cat "$EXEC_MUTEX_FILE"`
        if [ "$_FILE_CONTENT" = "$SEQNUM" ]; then
            _MUTEX_OWNED_BY_ME="y"
        fi
    done
}

fnTestIfMounted()
# $1 - The name of the variable to be set with outcome ("y"/"n").
################################################################################
{
    local _RESULT_VAR=$1
    local _RESULT="y"

    set +e
    local _MOUNT_ENTRY=`mount | grep "$USB_MPOINT"`
    set -e
    if [ "$_MOUNT_ENTRY" = "" ]; then
        _RESULT="n"
    fi

    eval $_RESULT_VAR="'$_RESULT'"
}

fnMount()
# $1 - The name of the variable to be set with success("y")/failure("n").
# $2 - Options description.
# All subsequent parameters - Options.
################################################################################
{
    local _RESULT_VAR=$1
    local _RESULT="n"

    fnLog $LL_PROGRESS "Attempting to mount $MDEV with $2 options ..."

    shift 2

    set +e
    mount -t auto $MDEV $USB_MPOINT $@
    local _MOUNT_RET_VAL=$?
    set -e
    if [ $_MOUNT_RET_VAL -ne 0 ]; then
        fnLog $LL_PROGRESS "... Failed."
    else
        fnLog $LL_PROGRESS "... Success."
        _RESULT="y"
    fi

    eval $_RESULT_VAR="'$_RESULT'"
}

fnConditionalSigSend()
# $1 - Signal to send.
# It's not entirely clear (to me at least) how the usbflag file is managed, but
# the current logic replicates that of the original script.
################################################################################
{
    if [ -f /opt/OxfordInstruments/cryosys/usbflag ]; then
        fnLog $LL_PROGRESS "Sending $1 signal to cryosys process ..."
        set +e
        killall $1 cryosys
        local _KILLALL_RET_VAL=$?
        set -e
        if [ $_KILLALL_RET_VAL -ne 0 ]; then
            fnLog $LL_PROGRESS "... killall failed. Exit code: $_KILLALL_RET_VAL"
        else
            fnLog $LL_PROGRESS "... Done."
        fi
    fi
}

fnUnmountDevice()
################################################################################
{
    fnLog $LL_PROGRESS "Unmounting USB device ..."
    set +e
    umount $USB_MPOINT
    local _UMOUNT_RET_VAL=$?
    set -e
    if [ $_UMOUNT_RET_VAL -ne 0 ]; then
        fnLog $LL_PROGRESS "... umount failed. Exit code: $_UMOUNT_RET_VAL"
    else
        fnLog $LL_PROGRESS "... Done."
    fi
}

fnCleanUpFS()
################################################################################
{
    fnLog $LL_PROGRESS "Cleaning up $USB_DEV ..."
    set +e
    rm -r $USB_DEV
    local _RM_RET_VAL=$?
    set -e
    if [ $_RM_RET_VAL -ne 0 ]; then
        fnLog $LL_PROGRESS "... rm failed. Exit code: $_RM_RET_VAL"
    else
        fnLog $LL_PROGRESS "... Done."
    fi
}

fnReleaseExecMutex()
################################################################################
{
    rm -f "$EXEC_MUTEX_FILE"
}

fnCleanAndExit()
################################################################################
{
    fnReleaseExecMutex
    fnLog $LL_PROGRESS "Terminating normally."
    exit 0
}

################################################################################
# Entry
################################################################################

fnLog $LL_PROGRESS "Launched."

fnDumpEnv

case "$ACTION" in
    add|"")
        fnWaitForAndAcquireExecMutex

        fnLog $LL_PROGRESS "Running."

        fnTestIfMounted NOW_MOUNTED

        if [ "$NOW_MOUNTED" = "y" ]; then
            fnLog $LL_PROGRESS "The USB device is already mounted."
            fnCleanAndExit
        fi

        fnMount MOUNT_SUCCESS "VFAT" "-o shortname=mixed"

        if [ "$MOUNT_SUCCESS" != "y" ]; then
            fnMount MOUNT_SUCCESS "no"
        fi

        if [ "$MOUNT_SUCCESS" = "y" ]; then
            fnLog $LL_OUTCOME "*** USB device detected as $MDEV $DEVPATH $SUBSYSTEM and mounted at $USB_MPOINT ***"
            echo "$MDEV" >> $USB_DEV
            fnConditionalSigSend "-SIGUSR1"
        else
            fnLog $LL_OUTCOME "*** Failed to mount USB device $MDEV ***"
        fi
        ;;
    remove)
        # We don't acquire the mutex for this because multiple removals running
        # concurrently isn't a problem, and it guarantees that USB stick removal
        # causes flag file cleanup.

        fnTestIfMounted NOW_MOUNTED

        if [ "$NOW_MOUNTED" != "y" ]; then
            fnLog $LL_PROGRESS "The USB device has already been unmounted."
            fnCleanAndExit
        fi

        fnUnmountDevice
        fnCleanUpFS

        fnLog $LL_OUTCOME "*** USB device $MDEV has been removed and unmounted ***"

        fnConditionalSigSend "-SIGUSR2"
        ;;
esac

fnCleanAndExit
