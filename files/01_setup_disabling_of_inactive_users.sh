#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

# Set up this instance to disable inactive users.
function setup {
  # Disable the "KDC:Disable Last Success" password plugin feature.
  # We don't want this feature enabled because we want to be able to
  # disable inactive users, which requires us to be able to determine
  # the last time a user authenticated.
  password_plugin_features=$(ipa config-show \
    |
    # --quiet means no printing unless the p command is used
    sed --quiet "s/^\s*Password plugin features:\s*\(.*\)/\1/p" \
    | tr "," "\n")
  # Build up the ipa config-mod command to run in a bash array.  We
  # need to include every password plugin feature _except_ for
  # KDC:Disable Last Success.
  cmd=(ipa config-mod)
  for feature in $password_plugin_features; do
    if [ "$feature" != "KDC:Disable Last Success" ]; then
      cmd+=(--ipaconfigstring="$feature")
    fi
  done
  # Run the ipa config-mod command.  Note that it is harmless to run
  # this command when it changes nothing.
  "${cmd[@]}"

  # Enable the systemd timer that runs the service that runs the
  # script that disables inactive users.
  systemctl daemon-reload \
    && systemctl enable disable-inactive-freeipa-users.timer
}

if [ $# -ne 0 ]; then
  echo This command takes no options.
  exit 255
fi

setup
