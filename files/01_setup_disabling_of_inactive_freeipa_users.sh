#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

# Set up this instance to disable inactive FreeIPA users.
function setup {
  # Disable the "KDC:Disable Last Success" password plugin feature.
  # We don't want this feature enabled because we want to be able to
  # disable inactive users, which requires us to be able to determine
  # the last time a user authenticated.
  #
  # Note that we read in the variable password_plugin_features as a
  # bash array (-a).  We also include the -r option to avoid mangling
  # backslashes.  The read bash builtin does not support long command
  # line options.
  IFS=',' read -a -r password_plugin_features <<< "$(ipa config-show \
    |
    # --quiet means no printing unless the p command is used
    sed --quiet "s/, /,/;s/^\s*Password plugin features:\s*\(.*\)/\1/p")"
  # Build up the ipa config-mod command to run in a bash array.  We
  # need to include every password plugin feature _except_ for
  # KDC:Disable Last Success.
  cmd=(ipa config-mod)
  for feature in "${password_plugin_features[@]}"; do
    if [ "$feature" != "KDC:Disable Last Success" ]; then
      cmd+=(--ipaconfigstring="$feature")
    fi
  done
  # Run the ipa config-mod command.
  #
  # Note that it is harmless to run this command when it changes
  # nothing; however, we must temporarily turn off the bash option
  # errexit since in that case the error code indicates a failure.
  set +o errexit
  "${cmd[@]}"
  set -o errexit

  # Create a role whose members are allowed to enable and disable
  # users.  By default FreeIPA servers cannot do this, so we need to
  # give them the permission to do so.
  #
  # Note that it is harmless to run these command when they change
  # nothing; but, we must temporarily turn off the bash option errexit
  # since in that case the error codes indicate a failure.
  set +o errexit
  ipa privilege-add "Enable/Disable Users" \
    --desc="Ability to enable and disable users"
  ipa privilege-add-permission "Enable/Disable Users" \
    --permissions="System: Unlock User"
  ipa privilege-add-permission "Enable/Disable Users" \
    --permissions="System: Read User Kerberos Login Attributes"
  ipa role-add "Enable/Disable Users" \
    --desc="Enable and disable users"
  ipa role-add-privilege "Enable/Disable Users" \
    --privileges="Enable/Disable Users"
  # Add the host group of FreeIPA servers to the role.
  ipa role-add-member "Enable/Disable Users" --hostgroups=ipaservers
  set -o errexit

  # Enable and start the systemd timer that runs the service that runs
  # the script that disables inactive users.
  systemctl daemon-reload
  systemctl enable disable-inactive-freeipa-users.timer
  systemctl start disable-inactive-freeipa-users.timer
}

if [ $# -ne 0 ]; then
  echo This command takes no options.
  exit 255
fi

setup
