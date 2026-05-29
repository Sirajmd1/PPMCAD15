# Ansible: Hands-On Labs
## Ansible Fundamentals & Playbooks

**Prerequisites**: create 2 ubuntu ec2 servers of type t3.small on AWS. 
Name one as "Control Node" and another as "Managed Node"

Control Node is where we install the Ansible server and Managed Node/s are the ones which are managed by Ansible.

---

## Lab 0: Setup

### 0.1 Install Ansible on "Control Node"

```bash
# Update package manager
sudo apt update

# Install Ansible (latest)
sudo apt install -y ansible

# Verify installation
ansible --version
```

### 0.2 Generate SSH Key (if not already done)

```bash
# Create SSH key
ssh-keygen -t rsa

# Display public key (copy for next step)
cat ~/.ssh/id_rsa.pub
```

### 0.3 Configure "Managed Nodes" (1 Ubuntu VMs)

On each managed node:
```bash
# Add your control node's SSH public key
echo "YOUR_PUBLIC_KEY" >> ~/.ssh/authorized_keys

# Set permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

---

## Lab 1: Create Inventory

### 1.1 Create inventory file

Create `inventory.yml`:
```yaml
---
all:
  vars:
    ansible_user: ubuntu
    ansible_key_file: ~/.ssh/id_rsa

  children:
    webservers:
      hosts:
        web1:
          ansible_host: 10.0.1.10 # provide the actual IP of the managed nodes
# an example when managing multiple nodes, add when you provision 2 managed nodes
    dbservers:
      hosts:
        db1:
          ansible_host: 10.0.1.20 # provide the actual IP of the managed nodes
```

### 1.2 Test connectivity

```bash
# Test all hosts
ansible all -i inventory.yml -m ping

# Expected output:
# web1 | SUCCESS => {
#     "ping": "pong"
# }
# ... (for all hosts)
```

---

## Lab 2: Ad-Hoc Commands

### Run shell commands

```bash
# Get uptime on webservers
ansible webservers -i inventory.yml -m shell -a 'uptime'

# Get free disk space
ansible all -i inventory.yml -m shell -a 'df -h /'

# Check OS version
ansible all -i inventory.yml -m shell -a 'cat /etc/os-release'
```

---

## Lab 3: First Playbook

### 3.1 Create basic playbook

Create `install-nginx.yml`:
```yaml
---
- name: Install and start Nginx
  hosts: webservers
  become: yes
  vars:
    nginx_port: 80

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Install Nginx
      apt:
        name: nginx
        state: present

    - name: Start Nginx service
      service:
        name: nginx
        state: started
        enabled: yes

    - name: Check if Nginx is running
      shell: systemctl is-active nginx
      register: nginx_status

    - name: Print Nginx status
      debug:
        msg: "Nginx status: {{ nginx_status.stdout }}"
```

### 3.2 Run the playbook

```bash
# Dry-run (--check): shows what would change without making changes
ansible-playbook -i inventory.yml install-nginx.yml --check

# Run for real
ansible-playbook -i inventory.yml install-nginx.yml

# Run with verbose output
ansible-playbook -i inventory.yml install-nginx.yml -v

# Even more verbose (shows SSH details)
ansible-playbook -i inventory.yml install-nginx.yml -vv
```

### 3.3 Verify idempotency

Run the playbook again:
```bash
ansible-playbook -i inventory.yml install-nginx.yml
```

**Expected**: All tasks show "ok" (no changes), demonstrating idempotency.

---

## Lab 4: Handlers

### 4.1 Create playbook with handlers

Create `nginx-config.yml`:
```yaml
---
- name: Configure Nginx
  hosts: webservers
  become: yes

  tasks:
    - name: Copy Nginx configuration
      copy:
        src: ./nginx.conf
        dest: /etc/nginx/nginx.conf
      notify: restart nginx

    - name: Create web directory
      file:
        path: /var/www/myapp
        state: directory
        owner: www-data
        group: www-data

    - name: Create index page
      copy:
        content: "<h1>Hello from {{ inventory_hostname }}</h1>"
        dest: /var/www/myapp/index.html
        owner: www-data
        group: www-data

  handlers:
    - name: restart nginx
      service:
        name: nginx
        state: restarted
```

### 4.2 Create nginx.conf file

Create `nginx.conf`:
```
user www-data;
worker_processes auto;

events {
    worker_connections 512;
}

http {
    server {
        listen 80;
        server_name _;

        location / {
            root /var/www/myapp;
            index index.html;
        }
    }
}
```

### 4.3 Run and test

```bash
# Run the playbook
ansible-playbook -i inventory.yml nginx-config.yml

# Open the port 80 on the security group of the "Managed Node" and open the public ip of the server on the browser
curl http://<public_ip_of_managed_node>

# Expected output: <h1>Hello from web1</h1>

# Verify handler runs once (run playbook again, change config)
# Handler only runs if notify is triggered
```

---

## Lab 5: Variables & Jinja2 Templates

### 5.1 Create template file

Create `index.html.j2`:
```html
<!DOCTYPE html>
<html>
<head>
    <title>{{ app_name }}</title>
</head>
<body>
    <h1>{{ app_name }} on {{ inventory_hostname }}</h1>
    <p>Server IP: {{ ansible_default_ipv4.address }}</p>
    <p>OS: {{ ansible_distribution }} {{ ansible_distribution_version }}</p>
    <ul>
        {% for item in features %}
        <li>{{ item }}</li>
        {% endfor %}
    </ul>
    <p>Environment: {{ environment }}</p>
</body>
</html>
```

### 5.2 Create playbook with variables

Create `deploy-app.yml`:
```yaml
---
- name: Deploy application with templates
  hosts: webservers
  become: yes

  vars:
    app_name: "My Production App"
    environment: "production"
    features:
      - "FastAPI Backend"
      - "PostgreSQL Database"
      - "Redis Cache"

  tasks:
    - name: Deploy index page from template
      template:
        src: index.html.j2
        dest: /var/www/myapp/index.html
        owner: www-data
        group: www-data
      notify: reload nginx

    - name: Display deployment info
      debug:
        msg: |
          Deployed {{ app_name }} to {{ inventory_hostname }}
          Environment: {{ environment }}
          Features: {{ features | join(', ') }}

  handlers:
    - name: reload nginx
      service:
        name: nginx
        state: reloaded
```

### 5.3 Run and verify

```bash
# Run playbook
ansible-playbook -i inventory.yml deploy-app.yml

# Check rendered template
ansible web1 -i inventory.yml -m shell -a 'cat /var/www/myapp/index.html'

# Test in browser
```

---

## Lab 6: Ansible Vault

### 6.1 Create vault file

```bash
# Create encrypted file
ansible-vault create secrets.yml

# When prompted, enter password (e.g., "ansible123")
```

Add to `secrets.yml`:
```yaml
---
db_password: "super_secret_password_123"
api_key: "sk-12345abcdef"
ssl_key: |
  -----BEGIN PRIVATE KEY-----
  MIIEvQIBADANBgkqhkiG9w0BAQE...
  -----END PRIVATE KEY-----
```

### 6.2 Use secrets in playbook

Create `deploy-with-secrets.yml`:
```yaml
---
- name: Deploy with encrypted secrets
  hosts: all
  become: yes

  vars_files:
    - secrets.yml

  tasks:
    - name: Display secret variable (DO NOT DO IN PRODUCTION)
      debug:
        msg: "DB Password: {{ db_password }}"
      no_log: yes

    - name: Create config file with secrets
      template:
        src: app.conf.j2
        dest: /etc/app/config.conf
        owner: root
        group: root
        mode: '0600'
      no_log: yes
```

### 6.3 Run with vault

```bash
# Run playbook (will prompt for vault password)
ansible-playbook -i inventory.yml deploy-with-secrets.yml --ask-vault-pass

# Or store password in file (not recommended for production!)
echo "ansible123" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Then run without prompt
ansible-playbook -i inventory.yml deploy-with-secrets.yml \
  --vault-password-file ~/.vault_pass

# View encrypted file
ansible-vault view secrets.yml

# Edit encrypted file
ansible-vault edit secrets.yml

# Decrypt (creates unencrypted copy)
ansible-vault decrypt secrets.yml
```

---

## Lab 7: Setup

### 7.1 Directory Structure

```bash
# Create project directory
mkdir -p learn-ansible-roles
cd learn-ansible-roles

# Create directories
mkdir -p roles/{nginx,java}
mkdir inventory

# Create inventory file from Session 1
cat > inventory/hosts.yml << 'EOF'
---
all:
  vars:
    ansible_user: ubuntu
    ansible_key_file: ~/.ssh/id_rsa

  children:
    webservers:
      hosts:
        web1:
          ansible_host: 10.0.1.10 # change with your managed servers IPs
        web2:
          ansible_host: 10.0.1.11 # change with your managed servers IPs

    appservers:
      hosts:
        app1:
          ansible_host: 10.0.1.30 # change with your managed servers IPs
EOF
```

---

## Lab 8: Create Nginx Role

### 8.1 Create role directory structure

```bash
cd roles/nginx

mkdir -p tasks handlers defaults vars templates files meta

# Create empty main.yml files
touch tasks/main.yml handlers/main.yml defaults/main.yml \
      vars/main.yml templates/main.yml meta/main.yml
```

### 8.2 Define tasks/main.yml

Create `roles/nginx/tasks/main.yml`:
```yaml
---
- name: Install Nginx
  apt:
    name: nginx
    state: present
    update_cache: yes
  tags: [install, web]

- name: Copy Nginx configuration template
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
    backup: yes
  notify: restart nginx
  tags: [config, web]

- name: Create web directory
  file:
    path: "{{ web_root }}"
    state: directory
    owner: "{{ nginx_user }}"
    group: "{{ nginx_user }}"
    mode: '0755'
  tags: [setup, web]

- name: Deploy index page
  template:
    src: index.html.j2
    dest: "{{ web_root }}/index.html"
    owner: "{{ nginx_user }}"
    group: "{{ nginx_user }}"
  tags: [deploy, web]

- name: Enable and start Nginx
  service:
    name: nginx
    state: started
    enabled: yes
  tags: [service, web]

- name: Configure firewall (ufw)
  ufw:
    rule: allow
    port: "{{ nginx_port }}"
    proto: tcp
  become: yes
  when: enable_firewall
  tags: [firewall, web]
```

### 8.3 Define handlers/main.yml

Create `roles/nginx/handlers/main.yml`:
```yaml
---
- name: restart nginx
  service:
    name: nginx
    state: restarted

- name: reload nginx
  service:
    name: nginx
    state: reloaded

- name: test nginx config
  shell: nginx -t
  become: yes
```

### 8.4 Define defaults/main.yml

Create `roles/nginx/defaults/main.yml`:
```yaml
---
# Nginx configuration defaults (lowest precedence)
nginx_port: 80
nginx_user: www-data
nginx_worker_processes: auto
nginx_worker_connections: 512

web_root: /var/www/html
server_name: _

# Features
enable_ssl: false
enable_firewall: false
enable_gzip: true

# HTML variables
app_title: "Welcome to Nginx"
app_description: "Running on Ansible"
```

### 8.5 Define vars/main.yml (optional overrides)

Create `roles/nginx/vars/main.yml`:
```yaml
---
# Role-specific variables (higher precedence than defaults)
nginx_config_file: /etc/nginx/nginx.conf
nginx_service_name: nginx
nginx_pid_file: /var/run/nginx.pid
```

### 8.6 Create Jinja2 template

Create `roles/nginx/templates/nginx.conf.j2`:
```
user {{ nginx_user }};
worker_processes {{ nginx_worker_processes }};
pid {{ nginx_pid_file }};

events {
    worker_connections {{ nginx_worker_connections }};
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    {% if enable_gzip %}
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css text/xml text/javascript;
    {% endif %}

    server {
        listen {{ nginx_port }};
        server_name {{ server_name }};

        root {{ web_root }};
        index index.html;

        {% if enable_ssl %}
        # SSL configuration
        ssl_certificate /etc/ssl/certs/ssl.crt;
        ssl_certificate_key /etc/ssl/private/ssl.key;
        {% endif %}

        location / {
            try_files $uri $uri/ =404;
        }

        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php-fpm.sock;
        }
    }
}
```

### 8.7 Create index.html template

Create `roles/nginx/templates/index.html.j2`:
```html
<!DOCTYPE html>
<html>
<head>
    <title>{{ app_title }}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        code { background: #f4f4f4; padding: 2px 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>{{ app_title }}</h1>
        <p>{{ app_description }}</p>

        <h2>Server Information</h2>
        <ul>
            <li><strong>Hostname:</strong> <code>{{ inventory_hostname }}</code></li>
            <li><strong>IP Address:</strong> <code>{{ ansible_default_ipv4.address }}</code></li>
            <li><strong>OS:</strong> <code>{{ ansible_distribution }} {{ ansible_distribution_version }}</code></li>
            <li><strong>Kernel:</strong> <code>{{ ansible_kernel }}</code></li>
            <li><strong>CPUs:</strong> <code>{{ ansible_processor_vcpus }}</code></li>
            <li><strong>Memory:</strong> <code>{{ (ansible_memtotal_mb / 1024) | round(2) }} GB</code></li>
        </ul>

        <h2>Nginx Configuration</h2>
        <ul>
            <li><strong>Port:</strong> <code>{{ nginx_port }}</code></li>
            <li><strong>User:</strong> <code>{{ nginx_user }}</code></li>
            <li><strong>Worker Processes:</strong> <code>{{ nginx_worker_processes }}</code></li>
            <li><strong>Gzip Enabled:</strong> <code>{{ enable_gzip | bool | lower }}</code></li>
            <li><strong>SSL Enabled:</strong> <code>{{ enable_ssl | bool | lower }}</code></li>
        </ul>

        <h2>Deployment Info</h2>
        <p>Deployed by Ansible on <code>{{ ansible_date_time.iso8601 }}</code></p>
    </div>
</body>
</html>
```

### 8.8 Create meta/main.yml

Create `roles/nginx/meta/main.yml`:
```yaml
---
galaxy_info:
  author: 'DevOps Training'
  description: 'Ansible role to install and configure Nginx'
  license: 'MIT'
  min_ansible_version: 2.9
  platforms:
    - name: Ubuntu
      versions:
        - '18.04'
        - '20.04'
        - '22.04'

dependencies: []
```

---

## Lab 9: Create Java Role

### 9.1 Create role directory structure

```bash
cd roles/java

mkdir -p tasks handlers defaults vars files meta
touch tasks/main.yml handlers/main.yml defaults/main.yml \
      vars/main.yml files/README meta/main.yml
```

### 9.2 Define tasks/main.yml

Create `roles/java/tasks/main.yml`:
```yaml
---
- name: Add Java repository
  apt_repository:
    repo: "ppa:openjdk-r/ppa"
    state: present
  when: ansible_distribution == "Ubuntu"
  become: yes

- name: Update apt cache
  apt:
    update_cache: yes
  become: yes

- name: Install Java
  apt:
    name: "{{ java_package }}"
    state: present
  become: yes
  notify: java installed
  tags: [install]

- name: Set Java alternatives
  alternatives:
    name: java
    link: /usr/bin/java
    path: "{{ java_home }}/bin/java"
  become: yes
  when: java_home is defined

- name: Verify Java installation
  shell: java -version
  register: java_version
  changed_when: false
  tags: [verify]

- name: Display Java version
  debug:
    msg: "{{ java_version.stderr_lines }}"
  tags: [verify]

- name: Create application user
  user:
    name: "{{ app_user }}"
    home: "{{ app_home }}"
    shell: /bin/bash
    createhome: yes
  become: yes

- name: Create application directories
  file:
    path: "{{ item }}"
    state: directory
    owner: "{{ app_user }}"
    group: "{{ app_user }}"
    mode: '0755'
  loop:
    - "{{ app_home }}/bin"
    - "{{ app_home }}/lib"
    - "{{ app_home }}/config"
  become: yes
```

### 9.3 Define handlers/main.yml

Create `roles/java/handlers/main.yml`:
```yaml
---
- name: java installed
  debug:
    msg: "Java installed successfully"
```

### 9.4 Define defaults/main.yml

Create `roles/java/defaults/main.yml`:
```yaml
---
# Java installation
java_version: "11"
java_package: "openjdk-11-jdk"
java_home: "/usr/lib/jvm/java-11-openjdk-amd64"

# Application user
app_user: appuser
app_home: "/home/{{ app_user }}"
app_port: 8080

# JVM options
java_opts: "-Xmx512m -Xms256m"
java_gc_opts: "-XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

### 9.5 Define vars/main.yml

Create `roles/java/vars/main.yml`:
```yaml
---
java_alternatives_path: "/usr/bin/java"
```

### 9.6 Create meta/main.yml

Create `roles/java/meta/main.yml`:
```yaml
---
galaxy_info:
  author: 'DevOps Training'
  description: 'Ansible role to install and configure Java'
  license: 'MIT'
  min_ansible_version: 2.9

dependencies: []
```

---

## Lab 10: Master Playbook Using Both Roles

### 10.1 Create master playbook

Create `site.yml` in project root:
```yaml
---
- name: Deploy Web and App Infrastructure
  hosts: all
  become: yes

  vars:
    environment: production
    app_title: "Production App Server"

  pre_tasks:
    - name: Update all packages
      apt:
        update_cache: yes
        upgrade: dist
      when: upgrade_packages | default(false)

    - name: Install common tools
      apt:
        name: [curl, wget, git, htop, vim, telnet]
        state: present

  roles:
    - nginx
    - java

  post_tasks:
    - name: Deploy summary
      debug:
        msg: |
          Deployment complete!
          Nginx: http://{{ ansible_default_ipv4.address }}:{{ nginx_port }}
          Java: {{ java_version }}
          Environment: {{ environment }}
```

### 10.2 Create web server playbook

Create `deploy-webservers.yml`:
```yaml
---
- name: Deploy Nginx web servers
  hosts: webservers
  become: yes

  vars:
    nginx_port: 80
    nginx_worker_processes: 4
    enable_gzip: true
    enable_firewall: false
    app_title: "Web Tier - Production"

  roles:
    - nginx

  post_tasks:
    - name: Verify Nginx is running
      shell: curl -I http://localhost:{{ nginx_port }} | head -n1
      register: nginx_check
      changed_when: false

    - name: Show response
      debug:
        msg: "{{ nginx_check.stdout }}"
```

### 10.3 Create app server playbook

Create `deploy-appservers.yml`:
```yaml
---
- name: Deploy Java application servers
  hosts: appservers
  become: yes

  vars:
    java_version: "11"
    java_package: "openjdk-11-jdk"
    java_opts: "-Xmx1024m -Xms512m"
    app_user: javaapp
    app_port: 8080

  roles:
    - java

  tasks:
    - name: Create systemd service for app
      copy:
        content: |
          [Unit]
          Description=Java Application
          After=network.target

          [Service]
          Type=simple
          User={{ app_user }}
          Environment="JAVA_OPTS={{ java_opts }}"
          ExecStart=/usr/lib/jvm/java-11-openjdk-amd64/bin/java $JAVA_OPTS -jar /opt/app.jar
          Restart=always

          [Install]
          WantedBy=multi-user.target
        dest: /etc/systemd/system/javaapp.service
      become: yes

    - name: Enable service
      systemd:
        name: javaapp
        enabled: yes
        daemon_reload: yes
```

---

## Lab 11: Test with --check and --diff

### 11.1 Dry-run mode

```bash
# Run in check mode (no changes)
ansible-playbook -i inventory/hosts.yml deploy-webservers.yml --check

# Show what would change
ansible-playbook -i inventory/hosts.yml deploy-webservers.yml --check --diff

# Even more verbose
ansible-playbook -i inventory/hosts.yml deploy-webservers.yml --check --diff -vv
```

### 11.2 Test specific tag

```bash
# Only run tasks tagged 'install'
ansible-playbook -i inventory/hosts.yml deploy-webservers.yml --tags install

# Run everything except 'firewall' tasks
ansible-playbook -i inventory/hosts.yml deploy-webservers.yml --skip-tags firewall

# Test in check mode with tags
ansible-playbook -i inventory/hosts.yml deploy-webservers.yml --tags config --check --diff
```

### 4.3 Verify idempotency

```bash
# Run playbook multiple times
ansible-playbook -i inventory/hosts.yml deploy-webservers.yml
ansible-playbook -i inventory/hosts.yml deploy-webservers.yml
ansible-playbook -i inventory/hosts.yml deploy-webservers.yml

# Should see "changed: 0" after first run
```

---