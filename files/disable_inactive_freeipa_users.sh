#!/usr/bin/bash

# Usage:
#   disable_inactive_freeipa_users.sh [disable_time]
#
# Users are considered inactive if they have not logged in since
# disable_time.  If disable_time is not specified then a default value
# of "45 days ago" is used.
#
# The date/time must be specified so that it is understandable by the
# date command, which is the same as saying it must be understandable
# by coreutils.  See the "Date input formats" section of the info
# manual distributed with coreutils for more information on date/time
# formats:
# https://www.gnu.org/software/coreutils/manual/html_node/Date-input-formats.html

set -o nounset
set -o errexit
set -o pipefail

# Users are considered inactive if they have not logged in since this
# time.
#
# See the "Shell Parameter Expansion" section of the info manual
# distributed with bash for more details on this form of parameter
# assignment:
# https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
disable_time=${1:-45 days ago}

# Use a temp file for our Kerberos credentials cache, since it only
# needs to exist while this script is running.
KRB5CCNAME=$(mktemp)

function usage {
  cat << HELP
Usage:
  ${0##*/} [disable_time]

Users are considered inactive if they have not logged in since
disable_time.  If disable_time is not specified then a default value
of "45 days ago" is used.

The date/time must be specified so that it is understandable by the date
command, which is the same as saying it must be understandable by
coreutils.  See the "Date input formats" section of the info manual
distributed with coreutils for more information on date/time formats:
https://www.gnu.org/software/coreutils/manual/html_node/Date-input-formats.html
HELP
  exit 1
}

if [ $# -gt 1 ]; then
  usage
else
  # Convert disable_time into an integer representing seconds since
  # the epoch.
  disable_deadline=$(date --date="$disable_time" +%S)

  # kinit via the host's keytab.
  kinit -k -t /etc/krb5.keytab

  # Grab a list of all non-disabled FreeIPA users
  users=$(
    # Note that we disable the size and time limits normally in place
    # when running ipa user-find.
    ipa user-find --disabled=false --sizelimit=0 --timelimit=0 \
      |
      # --quiet means no printing unless the p command is used
      sed --quiet 's/^\s*User login:\s*//p'
  )

  for user in $users; do
    timestamps=$(ipa user-status "$user" \
      |
      # --quiet means no printing unless the p command is used
      sed --quiet 's/\s*Last successful authentication:\s*//p')
    # In the event that all timestamps are invalid (N/A) we don't want
    # to disable users since we don't know the last time they
    # authenticated.
    #
    # TODO: After disable_time has elapsed with the "KDC:Disable Last
    # Success" feature disabled we can start disabling users with all
    # authentication timestamps invalid (N/A).  See #74 for more
    # details.
    all_timestamps_invalid=true
    disable_user=true
    for timestamp in $timestamps; do
      # Do we have a valid timestamp in the format that the command
      # ipa user-status uses (YYYYMMDDHHMMSSZ)?
      if [[ $timestamp =~ ^([[:digit:]]{4})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})Z$ ]]; then
        # At least one timestamp is valid.
        all_timestamps_invalid=false

        # 1. Reformat the timestamp to ISO 8601 format so the date
        # command can understand it.
        # 2. Use the date command to convert the ISO 8601 timestamp to
        # seconds since the epoch.
        timestamp=${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}T${BASH_REMATCH[4]}:${BASH_REMATCH[4]}:${BASH_REMATCH[6]}Z
        timestamp=$(date --date="$timestamp" +%s)

        # If the timestamp postdates the deadline then the user is
        # active and should not be disabled.
        if ((timestamp > disable_deadline)); then
          disable_user=false
        fi
      fi
    done

    # Now that we have analyzed the last authentication timestamps,
    # disable users as necessary.
    #
    # TODO: Note also that after disable_time has elapsed with the
    # "KDC:Disable Last Success" feature disabled we can start
    # disabling users with all authentication timestamps invalid (N/A)
    # and simplify this logic.  See #74 for more details.
    if $disable_user; then
      if ! $all_timestamps_invalid; then
        ipa user-disable "$user"
        echo User "$user" disabled due to inactivity.
      else
        echo User "$user" not disabled because all authentication timestamps were invalid.
      fi
    else
      echo User "$user" not disabled due to sufficiently recent authentication.
    fi
  done

  # Destroy our Kerberos credentials cache.
  kdestroy
fi
