# E2E automation framework

This is a set of scripts that provision cloud instances, deploy K8S, tune nodes and deploy mayastor and other platforms

Provisioning is done via Terraform
The rest is done by Ansible
The glue script representing a pipeline is `up.sh`

## General approach

Each part of the process can be decoupled from the rest. We can skip provisioning or K8S installation if we have a working inventory for ansible plays to use, and a working Kubernetes setup for example.

All we require is ssh connectivity to the first master node in the inventory. It is used as the bastion host for `sshuttle` which provides VPN-like functionality right into the private network. If the host executing the scripts is already local to the rest of the setup, remove the `start_vpn` stage from `STAGES`

## Workflow

### Provision a cluster, deploy mayastor

1. Edit the `vars` file. Once support for additional platforms is present, the platform specific variables need to be set correctly as per the platform.
2. Run `up.sh`
3. Wait...

### Teardown the setup

Run `down.sh`

### `vars` file settings

The file is heavily commented, please review it before running `up.sh`
## Extending this framework

- Additional plays can be added to the `deployments` directory, and optionally added to `vars` under the `PLAYBOOKS` variable.
- Additional cloud platforms can be implemented under `prov/PLATFORM_NAME` as long as the TF code builds the same format of `inventory.ini`.
- Different Kubernetes (and Openshift) deployments and distributions can be added to `up.sh` as a function and triggered via the `vars` file `K8S_INSTALLER` variable.
- The `STAGES` variable describes the stages, and if a stage is to be skipped, it can be removed in `vars`.

