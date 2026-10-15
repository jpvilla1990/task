
# Deliverables

## 1. Ansible playbook


Ansible playbook contains hostnames mapped to different environments and different usercases, see `inventories/prod/hosts.yaml`.
File `inventories/prod/group_vars/all.yaml` contains common variables accross the playbook, there are secrets in there, so this file should be treated as a template, and be populated in production wherever the playbook is executed.

Run ansible:
```bash
ansible-playbook playbooks/site.yaml
```

The playbook `playbooks/site.yaml` runs several roles, only common contains relevant tasks, the other roles are empty to be populated on need.

## 2. Molecule

The following script runs the molecule tests, at the moment testing only common.
```bash
./molecule_test.sh
```

The file `molecule/default/molecule.yml` contains configuration of the test environment, there is a dockerfile to simulate assumptions on the received Ubuntu machines.

## 3. Idempodency

All tasks look at an desired state, for example:
```yaml
- name: Disable SSH password authentication
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^\s*#?\s*PasswordAuthentication\s+'
    line: 'PasswordAuthentication no'
    validate: '/usr/sbin/sshd -t -f %s'
  notify: Restart SSH
```

This task checks this line is defined in a specific way, if so the task is skipped.
Running plain bash commands was avoided to ensure idempotency.

## 4. Inventory Layout dev, staging, prod

Inventory layout for each environment is defined in `inventories/prod/hosts.yaml`.
For vault integration an additional task is suggested
```yaml
- name: Ensure known_hosts file exists
  file:
    path: "{{ known_hosts_file }}"
    state: touch
    mode: '0600'

- name: Scan all hosts and append to known_hosts
  shell: |
    ssh-keyscan -H {{ hostvars[item]['ansible_host'] }} >> {{ known_hosts_file }}
  loop: "{{ groups['all'] }}"

- name: Resolve VAULT_TOKEN
  ansible.builtin.set_fact:
    vault_token: "{{ lookup('env', 'VAULT_TOKEN') }}"

- name: Get Vault ssh keys using curl
  command: >
    curl -fsSkL --header "X-Vault-Token: {{vault_token}}" --request GET {{ hostvars[item]['vault_host'] }}/{{ hostvars[item]['vault_engine'] }}/{{ hostvars[item]['vault_ssh_secrets'] }}
  register: vault_ssh_keys_response

- name: Parse Vault ssh response JSON
  ansible.builtin.set_fact:
    vault_ssh_keys_response_json: "{{ vault_ssh_keys_response.stdout | from_json }}"

- name: Parse Vault SSH public keys
  ansible.builtin.set_fact:
    "{{ item }}_public_key": "{{ vault_ssh_keys_response_json.data[item ~ '_public_key'] }}"
  loop: "{{ admin_users }}"
```

Nevertheless to ensure it run just once, it could work as localhost once as an independent role, and then other roles capture its value, for sake of completeness this was not implemented since this role has conflicts with molecule (could not find a quick way to mock the variables set by the local role). Nevertheless to run this succesfully is required only a VAULT_TOKEN and a vault with the secrets preset, but for the implemented solution the secrets need to be populated in the production environment where the playbook is executed.

## 5. Ansible vs Chef

Ansible relies on an ssh connection to provision servers using a central node to perform updates.
Pros: Simple, perfect for small fleets, enforces changes centraly, ideal for bootstrapping servers.
Cons: Hard to maintain when fleet grows, central server is down then all updates are down.

Chef pulls updates changes from a central server, each server independently pulls changes.
Pros: No single point of failure, nodes independently keeps consistency.
Cons: Inconsistency between servers when poorly managed, not ideal for bootstrapping since it requires several configurations to be enabled.

Packer: Produce images with all dependencies already installed as a virtualized OS.
Pros: Better version control
Cons: Still requires automation to provision the image in the servers when an update is required.

Cloud Services: It would be a self managed extension of packer, where an image is configured to be deployed in a cloud environment. Using tools like terraform or crossplane VMs or docker images can be automatically deployed.

Pros: seamless automation, less infrastructure maintenance.
Cons: The provision configuration is entirely software, not ideal to provision physical hardware or embedded systems.

