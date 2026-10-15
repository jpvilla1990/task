#!/bin/bash

uv run ansible-galaxy collection install community.general ansible.posix
ANSIBLE_CONFIG="$PWD/ansible.cfg" ANSIBLE_ROLES_PATH="$PWD/roles" uv run molecule test
