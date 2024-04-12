# ansible-role-freeipa-server #

[![GitHub Build Status](https://github.com/cisagov/ansible-role-freeipa-server/workflows/build/badge.svg)](https://github.com/cisagov/ansible-role-freeipa-server/actions)
[![CodeQL](https://github.com/cisagov/ansible-role-freeipa-server/workflows/CodeQL/badge.svg)](https://github.com/cisagov/ansible-role-freeipa-server/actions/workflows/codeql-analysis.yml)

This is an Ansible role for installing
[FreeIPA](https://www.freeipa.org) server.

## Requirements ##

None.

## Role Variables ##

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| freeipa_days_before_inactive | The number of days a user can go without logging in before his or her account is determined to be inactive and is disabled. | `45` | No |
| freeipa_disable_trace | Whether or not to disable trace functionality for all HTTP and HTTPS requests. | `false` | No |
| freeipa_enable_hsts | Whether or not to return HSTS headers for all HTTP and HTTPS requests. | `false` | No |

## Dependencies ##

None.

## Installation ##

This role can be installed via the command:

```console
ansible-galaxy install --role-file path/to/requirements.yml
```

where `requirements.yml` looks like:

```yaml
---
- name: freeipa_server
  src: https://github.com/cisagov/ansible-role-freeipa-server
```

and may contain other roles as well.

For more information about installing Ansible roles via a YAML file,
please see [the `ansible-galaxy`
documentation](https://docs.ansible.com/ansible/latest/galaxy/user_guide.html#installing-multiple-roles-from-a-file).

## Example Playbook ##

Here's how to use it in a playbook:

```yaml
- hosts: freeipa_servers
  become: true
  become_method: sudo
  tasks:
    - name: Install FreeIPA server
      ansible.builtin.include_role:
        name: freeipa_server
```

## Contributing ##

We welcome contributions!  Please see [`CONTRIBUTING.md`](CONTRIBUTING.md) for
details.

## License ##

This project is in the worldwide [public domain](LICENSE).

This project is in the public domain within the United States, and
copyright and related rights in the work worldwide are waived through
the [CC0 1.0 Universal public domain
dedication](https://creativecommons.org/publicdomain/zero/1.0/).

All contributions to this project will be released under the CC0
dedication. By submitting a pull request, you are agreeing to comply
with this waiver of copyright interest.

## Author Information ##

Shane Frasier - <jeremy.frasier@gwe.cisa.dhs.gov>
