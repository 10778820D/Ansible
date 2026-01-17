#!/bin/bash

# Crear carpetas
mkdir -p app
mkdir -p ansible/inventories ansible/playbooks ansible/roles/node_app/{tasks,templates,handlers}
mkdir -p .github/workflows

# ansible.cfg
cat > ansible/ansible.cfg <<EOF
[defaults]
inventory = inventories/production.yml
host_key_checking = False
deprecation_warnings = False
EOF

# Inventario
cat > ansible/inventories/production.yml <<EOF
all:
  hosts:
    web1:
      ansible_host: 192.168.1.47  # REEMPLAZA por tu IP
      ansible_user: deploy
      ansible_python_interpreter: /usr/bin/python3
EOF

# Playbook
cat > ansible/playbooks/deploy.yml <<EOF
---
- name: Deploy Node.js app to production
  hosts: all
  become: no
  roles:
    - node_app
EOF

# Role: tasks/main.yml
cat > ansible/roles/node_app/tasks/main.yml <<EOF
---
- name: Ensure git is present
  apt:
    name: git
    state: present
  become: yes

- name: Ensure node (and npm) are installed
  apt:
    name: nodejs
    state: present
  become: yes

- name: Include deploy tasks
  import_tasks: deploy.yml
EOF

# Role: tasks/deploy.yml
cat > ansible/roles/node_app/tasks/deploy.yml <<EOF
---
- name: Ensure app dir exists
  file:
    path: /home/deploy/apps/myapp
    state: directory
    owner: deploy
    group: deploy
    mode: '0755'

- name: Checkout app code from repo (pull latest)
  git:
    repo: 'https://github.com/10778820D/Ansible.git'  # REEMPLAZA con tu repo
    dest: /home/deploy/apps/myapp
    version: "{{ git_ref | default('main') }}"
    force: yes
    update: yes
  become: no

- name: Install npm dependencies
  npm:
    path: /home/deploy/apps/myapp
    production: yes

- name: Copy systemd service file
  template:
    src: node-app.service.j2
    dest: /etc/systemd/system/myapp.service
  become: yes
  notify:
    - Reload systemd

- name: Ensure service is started and enabled
  systemd:
    name: myapp
    state: started
    enabled: yes
  become: yes
EOF

# Handler
cat > ansible/roles/node_app/handlers/main.yml <<EOF
---
- name: Reload systemd
  command: systemctl daemon-reload
  become: yes
EOF

# Template systemd
cat > ansible/roles/node_app/templates/node-app.service.j2 <<EOF
[Unit]
Description=My Node.js App
After=network.target

[Service]
User=deploy
WorkingDirectory=/home/deploy/apps/myapp
ExecStart=/usr/bin/node /home/deploy/apps/myapp/index.js
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# Workflow mínimo de GitHub Actions
cat > .github/workflows/ci-cd.yml <<EOF
name: CI/CD - Ansible Deploy
on:
  push:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Tests placeholder"
EOF

echo "✅ Estructura creada con archivos mínimos. Reemplaza IP y repo en los archivos según tu configuración."
