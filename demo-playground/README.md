# E2E automation framework

This is a set of scripts that provision cloud instances, deploy K8S, tune nodes and deploy mayastor and other platforms

Provisioning is done via Terraform
The rest is done by Ansible
The glue script representing a pipeline is `up.sh`

## General approach

Each part of the process can be decoupled from the rest. We can skip provisioning or K8S installation if we have a working inventory for ansible plays to use, and a working Kubernetes setup for example.

## Workflow

### Provision a cluster, deploy mayastor

1. Edit the `vars` file. Once support for additional platforms is present, the platform specific variables need to be set correctly as per the platform.
2. Run `up.sh`
3. Wait...

### Teardown the setup

Run `down.sh`

## Extending this framework

- Additional plays can be added to the `deployments` directory, and optionally added to `up.sh`
- Additional cloud platforms can be implemented under `prov/PLATFORM_NAME` as long as the TF code builds the same format of `inventory.ini` and `ssh.cfg`
