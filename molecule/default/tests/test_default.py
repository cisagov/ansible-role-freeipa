"""Module containing the tests for the default scenario."""

# Standard Python Libraries
import os

# Third-Party Libraries
import pytest
import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ["MOLECULE_INVENTORY_FILE"]
).get_hosts("all")


@pytest.mark.parametrize("pkg", ["freeipa-server"])
def test_packages(host, pkg):
    """Test that the appropriate packages were installed."""
    assert host.package(pkg).is_installed


@pytest.mark.parametrize(
    "f",
    [
        "/etc/cron.daily/disable_inactive_users.sh",
        "/usr/local/share/dhsca_fullpath.p7b",
        "/usr/local/share/dhsca_fullpath.pem",
        "/usr/local/sbin/setup_freeipa_replica.sh",
        "/usr/local/sbin/setup_freeipa_server.sh",
    ],
)
def test_files(host, f):
    """Test that the appropriate files were installed."""
    assert host.file(f).exists
    assert host.file(f).is_file
    assert host.file(f).user == "root"
    assert host.file(f).group == "root"
