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
  disable_deadline=$(date --date="$disable_time" +%s)

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

  # Grab the domain.
  #
  # --quiet means no printing unless the p command is used
  domain=$(resolvectl domain | sed --quiet 's/^[^:]*:\s\(.*cool\.cyber\.dhs\.gov\).*$/\1/p')

  # Construct the LDAP searchbase
  searchbase="cn=users,cn=accounts,dc="${domain//./,dc=}

  for user in $users; do
    # Do an LDAP query to get the timestamps corresponding to the
    # user's creation time and the user's last authentication time.
    ldapsearch_output=$(ldapsearch -Y GSSAPI -b "$searchbase" "uid=$user" createTimestamp krbLastSuccessfulAuth)

    # Extract the user's creation timestamp from the LDAP output.
    #
    # --quiet means no printing unless the p command is used
    create_timestamp=$(sed --quiet 's/^createTimestamp:\s//p' <<< "$ldapsearch_output")

    # Do we have a valid timestamp in the format that IPA and LDAP use
    # (YYYYMMDDHHMMSSZ)?
    if [[ $create_timestamp =~ ^([[:digit:]]{4})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})Z$ ]]; then
      # 1. Reformat the timestamp to ISO 8601 format so the date
      # command can understand it.
      # 2. Use the date command to convert the ISO 8601 timestamp to
      # seconds since the epoch.
      create_timestamp=${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}T${BASH_REMATCH[4]}:${BASH_REMATCH[4]}:${BASH_REMATCH[6]}Z
      create_timestamp=$(date --date="$create_timestamp" +%s)

      # This if skips any users that were created recently but have
      # not yet logged in.  We don't want to disable their access yet.
      if ((create_timestamp < disable_deadline)); then
        # Extract the user's last authentication timestamp from the
        # LDAP output.  Note that this timestamp may not exist if the
        # user has never logged in.
        #
        # --quiet means no printing unless the p command is used
        last_authentication_timestamp=$(sed --quiet 's/^krbLastSuccessfulAuth:\s//p' <<< "$ldapsearch_output")

        # Do we have a valid timestamp in the format that IPA and LDAP
        # use (YYYYMMDDHHMMSSZ)?
        if [[ $last_authentication_timestamp =~ ^([[:digit:]]{4})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})([[:digit:]]{2})Z$ ]]; then
          # 1. Reformat the timestamp to ISO 8601 format so the date
          # command can understand it.
          # 2. Use the date command to convert the ISO 8601 timestamp
          # to seconds since the epoch.
          last_authentication_timestamp=${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}T${BASH_REMATCH[4]}:${BASH_REMATCH[4]}:${BASH_REMATCH[6]}Z
          last_authentication_timestamp=$(date --date="$last_authentication_timestamp" +%s)
        else
          # The timestamp may not exist, but it should never exist but
          # not match the regex above.
          if [[ -n $last_authentication_timestamp ]]; then
            echo User "$user" has an invalid last authentication timestamp.
          fi
        fi

        # If the timestamp predates the deadline, or if the user has
        # never authenticated at all, then the user is inactive and
        # should be disabled.
        if [[ -z $last_authentication_timestamp ]] || ((last_authentication_timestamp < disable_deadline)); then
          ipa user-disable "$user"
          echo User "$user" disabled due to inactivity.
        else
          echo User "$user" not disabled due to sufficiently recent authentication.
        fi
      else
        echo User "$user" created too recently for inactivity to be determined.
      fi
    else
      # It should be impossible to reach this statement; all creation
      # timestamps should be valid.
      echo The creation timestamp for "$user" is invalid.
    fi
  done

  # Destroy our Kerberos credentials cache.
  kdestroy
  rm "$KRB5CCNAME"
fi
