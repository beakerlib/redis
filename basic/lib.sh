#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k syntax=beakerlib
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/redis/Library/basic
#   Description: Redis test library
#   Author: Jakub Prokes <jprokes@redhat.com> and Jan Houska <jhouska@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   library-prefix = basic
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 NAME

redis/basic - Redis test library

=head1 DESCRIPTION

This is a trivial example of a BeakerLib library. It's main goal
is to provide a minimal template which can be used as a skeleton
when creating a new library. It implements function fileCreate().
Please note, that all library functions must begin with the same
prefix which is defined at the beginning of the library.

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Variables
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 VARIABLES

Below is the list of global variables. When writing a new library,
please make sure that all global variables start with the library
prefix to prevent collisions with other libraries.

=over


=item redisCOLLECTION

Set to 1 when running in collection. 0 otherwise.


=item redisCOLLECTION_NAME

Set to collection name. Empty if there is no redis in COLLECTIONS.


=item redisPACKAGE_PREFIX

Prefix which differ RHSCL package name from distribution.
Where no software collection set is empty.


=item redisSERVICE_NAME

Service name, usable in case of dual component or RHSCL.


=item redisROOT_DIR

Path where are stored binaries, doc files etc.


=item redisVAR_DIR

Path where variable data could be found.


=item redisCONFIG_DIR

Path where redis default configuration files (redis.conf and redis-sentinel) are sotred.


=item redisSENTINEL_CONF

Default path where redis-sentinel.conf configuration file is stored.


=item redisStandOutputLog
=item redisErrorLog

Variable contains name of file which contains error output of last command

=back

=cut

declare redisStandOutputLog;
declare redisErrorLog;


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 FUNCTIONS

=head2 redisCLI

Wraper for redis-cli

    redisCLI <args> [exit_code [message]]

    '--fail'  argument cause that commnad should trigger error message. The error is desired.

=over

=item args

Arguments pass trough to redis-cli, see man redis-cli.

=item exit_code

Expected exit code

=item message

Descriptive message displayed instead of <args> in journal.

=back

Return value is equal to redis-cli.

=cut

function redisCLI() {

    if [[ $1 != "--fail" ]]; then
        local command="$*";
    else
        local command="${*:2}";
    fi

    local eRC=${2:-0};
    local message=${3:-$command};

    type redis-cli &>/dev/null || {
        rlFail "redis-cli not found. Check PATH?";
        return 127;
    }

    workingFolder=$(mktemp -d)
    redisErrorLog="$workingFolder/error.log";
    redisStandOutputLog="$workingFolder/stdoutput.log";

    rlLogDebug "Executing: 'redis-cli $command'";

    varx="redis-cli "${command};
    eval "$varx" 2>$redisErrorLog  > $redisStandOutputLog;


    if [[ -s  $redisErrorLog ]] || grep '(error)\|ERR' $redisStandOutputLog; then
        if [[ $1 != "--fail" ]]; then
            rlFail "$message";
            fceReturn=2;
        else
            rlPass "The command \"$message\" is failing according expectations!";
            fceReturn=0;
        fi
    else
        if [[ $1 != "--fail" ]]; then
            rlPass "$message";
            fceReturn=0;
        else
            rlFail "The command \"$message\" is failing according expectations!";
            fceReturn=2;
        fi
    fi

    ## cleaning
    cat $redisErrorLog
    cat $redisStandOutputLog

    rm -r $workingFolder;
    return $fceReturn;
}



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Execution
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 EXECUTION

This library supports direct execution. When run as a task, phases
provided in the PHASE environment variable will be executed.
Supported phases are:

=over

=item Create

Create a new empty file. Use FILENAME to provide the desired file
name. By default 'foo' is created in the current directory.

=item Test

Run the self test suite.

=back

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Verification
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a verification callback which will be called by
#   rlImport after sourcing the library to make sure everything is
#   all right. It makes sense to perform a basic sanity test and
#   check that all required packages are installed. The function
#   should return 0 only when the library is ready to serve.

function basicLibraryLoaded() {

    rlLogDebug "COLLECTIONS='$COLLECTIONS'"

    if [[ -n ${COLLECTIONS} ]]; then
        rlLogInfo "------------------------------------------"
        rlLogInfo "COLLECTIONS variable contain some inputs!!"
        rlLogInfo "COLLECTIONS=$COLLECTIONS"
        rlLogInfo "------------------------------------------"
        for collection in $COLLECTIONS; do
            rlLogInfo "-----  listed in COOLLECTIONS variable -----"
            rlLogInfo "Current collection: '$collection'"
            if echo "$collection" | grep -w 'rh-redis[0-9]\+'; then
                    readonly redisCOLLECTION=1;
                    readonly redisCOLLECTION_NAME="${collection}";
                    readonly redisPACKAGE_PREFIX="${redisCOLLECTION_NAME}-";
                    readonly redisSERVICE_NAME="${redisPACKAGE_PREFIX}redis";
                    readonly redisROOT_DIR="/opt/rh/${redisCOLLECTION_NAME}/root";
                    readonly redisVAR_DIR="/var/opt/rh/${redisCOLLECTION_NAME}";
                    readonly redisCONFIG_DIR="/etc/opt/rh/${redisCOLLECTION_NAME}";
		    readonly redisSENTINEL_CONF=/opt/rh/${redisCOLLECTION_NAME}/register.content/etc/opt/rh/${redisCOLLECTION_NAME}
                    break;
            fi;
        done;
        rlLogInfo "----- /listed in COOLLECTIONS variable -----"
    fi

    # Basic setting in case of redis is a module not a collection:
    if [[ -z "${redisCOLLECTION}" ]]; then
        readonly redisCOLLECTION=0;
        readonly redisCOLLECTION_NAME="";
        readonly redisPACKAGE_PREFIX="redis-";
        readonly redisSERVICE_NAME="redis";
        readonly redisROOT_DIR="";
        readonly redisVAR_DIR="/var";
        readonly redisCONFIG_DIR="/etc";
	readonly redisSENTINEL_CONF="/etc"
    fi


    # report what is set:
    rlLogInfo "========================================"
    rlLogInfo "redisCOLLECTION=$redisCOLLECTION";
    rlLogInfo "redisCOLLECTION_NAME=$redisCOLLECTION_NAME";
    rlLogInfo "redisPACKAGE_PREFIX=$redisPACKAGE_PREFIX";
    rlLogInfo "redisSERVICE_NAME=$redisSERVICE_NAME";
    rlLogInfo "redisROOT_DIR=$redisROOT_DIR";
    rlLogInfo "redisVAR_DIR=$redisVAR_DIR";
    rlLogInfo "redisCONFIG_DIR=$redisCONFIG_DIR";
    rlLogInfo "redisSENTINEL_CONF=$redisSENTINEL_CONF";
    rlLogInfo "========================================"


    if [[ "${redisCOLLECTION}" == 1 ]]; then

        if rpm -q "${redisCOLLECTION_NAME}"; then
            rlLogDebug "${redisCOLLECTION_NAME} installed"
            rlLogInfo  "${redisCOLLECTION_NAME} installed"
        else
            rlLogDebug "${redisCOLLECTION_NAME} not installed!!!"
            return 1
        fi

        if rpm -q "${redisSERVICE_NAME}"; then
            rlLogDebug "${redisSERVICE_NAME} installed"
            rlLogInfo  "${redisSERVICE_NAME} installed"
        else
            rlLogDebug "${redisSERVICE_NAME} not installed!!!"
            rlLogInfo  "${redisSERVICE_NAME} not installed!!!"
            return 1
        fi

    else

        if rpm -q redis; then
            rlLogDebug "redis package installed"
            rlLogInfo  "redis package installed"
        else
            rlLogDebug "redis package not installed!!!"
            rlLogInfo  "redis package not installed!!!"
            return 1
        fi

    fi

    return 0
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Authors
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Jakub Prokes <jprokes@redhat.com>
Jan Houska <jhouska@redahat.com>

=back

=cut
