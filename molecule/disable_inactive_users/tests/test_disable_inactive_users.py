"""Module containing the tests for the disable_inactive_users scenario."""

# Standard Python Libraries
import os

# Third-Party Libraries
import pytest
import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ["MOLECULE_INVENTORY_FILE"]
).get_hosts("all")


@pytest.mark.parametrize(
    "f",
    [
        "/etc/systemd/system/disable-inactive-freeipa-users.service",
        "/etc/systemd/system/disable-inactive-freeipa-users.timer",
        "/usr/local/sbin/01_setup_disabling_of_inactive_freeipa_users.sh",
        "/usr/local/sbin/disable_inactive_freeipa_users.sh",
    ],
)
def test_files(host, f):
    """Verify the appropriate files were installed."""
    assert host.file(f).exists
    assert host.file(f).is_file
    assert host.file(f).user == "root"
    assert host.file(f).group == "root"


@pytest.mark.parametrize(
    "f",
    [
        "/etc/systemd/system/disable-inactive-freeipa-users.service",
        "/etc/systemd/system/disable-inactive-freeipa-users.timer",
    ],
)
def test_verify_systemd_units(host, f):
    """Verify systemd can parse the unit files we created."""
    cmd = host.run(f"systemd-analyze verify {f}")
    assert cmd.rc == 0
