# Ansible & Configuration Management - Introductory Notes

## 1. Container World vs. Traditional Server World

### Container world (EKS, ECS, self-managed Kubernetes)

You stand up a container orchestrator cluster (e.g., EKS, ECS, self-managed Kubernetes). A cluster is made of:

- A **control plane** (master)
- One or more **worker nodes**

Your application runs on the worker nodes but it runs as a **container**, not as a process on the host.

Because the app runs as a container, the host does **not** need any pre-installed runtimes. Everything the app depends on is baked into the container image. The recipe lives in a `Dockerfile`, where you declare:

- The base OS the app will run on
- The packages the app needs
- The language runtime (Java / Python / Node.js / ...)
- How to start the app

### Virtual machine / physical server

Same app, very different reality:

- To run `java -jar app.jar`, the JVM has to be **pre-installed** on the box. Otherwise the command fails.
- Same story for Python, Node.js, Ruby, the runtime is a host-level dependency.
- Web servers like Apache or Nginx need both the package installed AND a stack of configuration files (`nginx.conf`, virtual host files, SSL certs, ...).

---

## 2. The Manual Configuration Problem

Doing this **once** is fine. Doing it on **5 servers** is annoying. Doing it across **dev / qa / uat / prod** is where it falls apart.

Typical pain:

1. You SSH into each server, install the package, hand-craft the config files.
2. You finish server 1, test it, then have to sync those files to the other 4.
3. During the next change or upgrade, anything you tweak by hand is easy to forget on the other servers.

> **Classic drift scenario:** I tuned something in QA but forgot to apply it in dev, UAT, and prod. Now QA behaves one way and prod behaves another, and nobody knows why.

---

## 3. Scripts Help, But Aren't Enough

The first instinct is automation via:

- Shell scripts
- Batch / PowerShell scripts

These help, but they have real limits:

- They don't enforce any framework or convention.
- They are **not idempotent**, i.e. running the same script twice can produce different results (e.g., a line gets appended to a file twice).
- Conditional logic for per-environment differences becomes spaghetti very quickly.

Example of branching configuration needs:

```
nginx.conf (dev, qa)    → listen on port 80 (HTTP)
nginx.conf (uat, prod)  → listen on port 443, redirect any port 80 (HTTP) request → 443
```

---

## 4. Configuration Management (CM)

> **Configuration Management** is the practice of configuring a server with packages, files, services, users and keeping it in the **desired state** going forward.

Things a CM tool typically manages on a server: the SSH daemon config, `sudoers`, system users, installed packages, service state, config files, scheduled jobs, and so on.

### The major tools

| Tool | Language | Model | Notes |
| --- | --- | --- | --- |
| **Puppet, Chef** | Ruby | Pull | First generation in this space. |
| **Ansible** | Python | Push | Launched by Red Hat ~2 years later. Config is standard **YAML**, which makes it easier to pick up. |

---

## 5. CM Architecture

Every CM tool boils down to two roles:

| Role | Purpose |
| --- | --- |
| **Control node** (master) | Where you declare the desired state e.g., "server `10.34.23.23` should have Nginx and Java installed, with these `nginx.conf` files." |
| **Managed nodes** | The servers being configured. Could be anywhere from 1 to 100,000+ nodes. |

```
Control Node ──────────────► Managed Node
                 apply the desired state on it
```

---

## 6. Pull vs. Push

### Pull model (Chef, Puppet)

Every managed node runs an **agent** (e.g., `chef-client`, `puppet-agent`). The agent connects to the control node, **pulls** the desired state, and applies it on itself.

```
Control Node ◄────────────── Managed Node
                 agent pulls the desired state from the CN
```

**Q. How does the agent know when to pull?**

It doesn't, on its own. It depends on the process your team agrees on:

- If you're confident that managed nodes won't carry manual changes (drift) that need to be preserved, run a basic `cron` job on each node to sync from the control node every 15 minutes (or whatever cadence works).
- Otherwise, trigger the agent manually after each change.

**Q. With 1,000 servers, how do you install the agent on all of them in the first place?**

A few options:

- **Golden image:** when VMs are provisioned (e.g., via VMware), bake the agent into the machine image.
- **Cloud-native bootstrapping:** AWS EC2 `user-data`, Azure custom script extensions, GCP startup scripts.
- **One-time manual script:** a shell script that takes a list of IPs and the agent version, then SSHes in and installs.

### Push model (Ansible)

The control node **pushes** the desired state to the managed nodes and applies it there. No agent is required on the targets, just SSH (Linux) or WinRM (Windows), plus Python (already present on most Linux distros).

```
Control Node ──── SSH / WinRM ────► Managed Node
                  CN pushes desired state to MN
```

**Q. Does SSH support PEM / PPK / password authentication?**

PEM keys and passwords both work. PPK is PuTTY's format, convert it to PEM if you're invoking SSH directly.

**Q. With 1,000 servers, how do you set up SSH access for all of them?**

A few options:

- **Golden image:** when provisioning via VMware (or similar), pre-load the control node's **public key** into `~/.ssh/authorized_keys` on the image.
- **One-time manual setup:** after each managed node is provisioned, add the control node's public key to that node's `authorized_keys` (a single `ssh-copy-id` call per host).

### Pull vs. Push at a glance

| | **Pull** (Chef / Puppet) | **Push** (Ansible) |
| --- | --- | --- |
| Agent on managed node? | Yes | No |
| Direction of network flow | Node → Control | Control → Node |
| Trigger | Cron / on-demand on the node | Run from the control node |
| Easier for ad-hoc commands? | No | Yes |
| Initial setup cost | Higher (install agents everywhere) | Lower (just SSH access) |

---

## 7. Inventory: Who Are We Managing?

Ansible needs a list of which hosts to act on. That list is the **inventory**.

- **Static inventory** — a file (INI or YAML) that lists hosts and groups by hand. Good when the set of servers is stable and known up front.
- **Dynamic inventory** — Ansible asks an external source (AWS EC2, Azure, GCP, vSphere, ...) for the live list of hosts at runtime. Good for cloud environments where instances come and go.
