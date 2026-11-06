# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of bash scripts that build Amazon Machine Images (AMIs) and wire them into auto-scaled server setups using the AWS CLI directly — no Packer/Puppet/Chef. There is no build system, linter, or test suite; the scripts are run directly with `bash`.

Prerequisites: AWS CLI, `jq`. Optional: `msee` (pretty help output), GNU coreutils on macOS (`gdate` is used by `create-ami.sh`).

## The 5-step pipeline

Scripts are run in this order (each supports `-h 1` for help):

1. `create-ami-creator-role.sh` — one-time: creates the `role-ami-creator` IAM role from `policies/`.
2. `create-ami.sh -u ami-templates/ami-template-<name>.sh -k <key-pair> -i role-ami-creator` — boots a temporary EC2 build instance that creates the AMI.
3. `create-server-role.sh` — creates the IAM role the servers run with.
4. `create-launch-template.sh -I <new ami id> ... -u server-boot/server-boot-<name>.sh -n lt-<name>` — creates a Launch Template, or a **new version** if the template already exists. (Launch Configurations are deprecated by AWS; the old `create-launch-config.sh` was removed.)
5. `create-auto-scaling-group.sh -l lt-<name>` — creates an Auto Scaling Group pinned to the launch template's `$Latest` version, so re-running step 4 updates what new servers boot from. Roll running servers with `aws autoscaling start-instance-refresh`.

`update-session-token.sh` is a standalone helper: interactive MFA login that writes a `<profile>_session` AWS profile via `aws sts get-session-token`.

When run with missing required flags, each script prints the flag's usage *and queries AWS to list existing valid values* (key pairs, roles, subnets, security groups, images) — preserve this pattern when modifying them. `create-ami.sh` finishes by printing the exact `create-launch-template.sh` command to run next.

## How the AMI build actually works

`create-ami.sh` does **not** build anything locally. It runs `aws ec2 run-instances` with an `ami-templates/*.sh` file as cloud-init user-data. That script executes on the build instance: installs software, then calls `aws ec2 create-image --no-reboot` **on itself** (this is why the instance needs the `role-ami-creator` instance profile). AMI names are auto-generated as `<name>-ami-YYYY-MM-DD_<n>` with `<n>` incremented by querying existing images. The node and mongodb templates then wait for the image to become available and shut the build instance down (shutdown behavior is `terminate`); simple-blog requires manual steps (Dropbox linking) and manual termination.

Defaults: region `eu-west-1`, base AMI resolved at run time to the latest Ubuntu 24.04 LTS via Canonical's public SSM parameter (`-b` overrides), root volume from `block-device-mapping.json` (100 GB gp3). Instance metadata calls in templates must use IMDSv2 (token-based), and `awscli` is installed via the AWS CLI v2 zip installer — the apt package no longer exists on Ubuntu 24.04. Several template/boot scripts also hardcode `--region eu-west-1` inline.

## Two-file naming convention

Each server type `<name>` is a pair — keep both in sync when adding a new type:

- `ami-templates/ami-template-<name>.sh` — user-data for the AMI build instance (bakes software into the image). Node versions are pinned per template (one `NODE_VERSION` variable near the top) so each codebase updates independently.
- `server-boot/server-boot-<name>.sh` — runs at every instance boot: clones the app repo, writes config to `/srv/config/`, installs and starts the app. `create-launch-template.sh` embeds this file **directly into the launch template user-data** — a boot-script change takes effect by creating a new template version, not by pushing to GitHub.

Only node, mongodb, and simple-blog have been modernized for Ubuntu 24.04 / launch templates. The remaining `launch-configurations/launch-config-*.sh` stubs (curl-from-GitHub-master) and other templates are historical and predate the migration. mongodb servers are launched by hand (pre-attached ENIs/EBS volumes — see the notes inside its template), so no launch template is used for them.

Secrets: files matching `launch-configurations/secret-*.sh` are gitignored. `create-launch-template.sh -s <secret file>` prepends the secret file to the user-data, so env vars/keys stay out of the repo and out of the public server-boot scripts.

## Debugging a failed image build

SSH to the build instance (`ubuntu@<ip>`), then:
- `less /var/log/cloud-init-output.log` — build log
- `sudo /var/lib/cloud/instance/scripts/part-001` — re-run the template script (edit it in place to iterate, then port fixes back to the local `ami-template-*.sh`)
