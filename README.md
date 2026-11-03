# t3code-provision

Terraform for one NIPA Cloud VM that runs T3 Code as a linked environment, so agents on your laptop can delegate builds and tests to it.

## Layout

- `terraform/` holds the VM, a persistent data volume, a floating IP, a key pair and an SSH-only security group.
- `terraform/cloud-init.yaml.tftpl` mounts the volume at `/srv/t3`, links `~/.t3`, `~/.claude`, `~/.codex`, `~/.config/gh` and `~/workspace` into it, installs `t3`, Claude Code and Docker, and writes the two files below.
- `/etc/t3code/policy.json` is a T3 Code managed policy that turns on Linked environments. Without it the VM refuses every link until someone flips Settings > Labs for it.
- `~/.config/systemd/user/t3code.service.d/provider-env.conf` loads `~/.t3/provider.env` into the T3 service. `t3 up` rewrites the service unit, so the credentials ride in a drop-in instead.
- `bin/t3env` wraps the lifecycle.

## Prerequisites

- A working `ncp-devops` entry in `~/.config/openstack/clouds.yaml` with its application credential in `secure.yaml`. Terraform reads it through `cloud = "ncp-devops"`, so no secret goes into tfvars or state. Check it with `OS_CLOUD=ncp-devops openstack token issue`.
- `terraform/terraform.tfvars`, copied from the example, with real image, network and floating IP pool names from `openstack image list`, `openstack network list` and `openstack network list --external`.
- `t3_channel` set to the release train of the machine you link from (`t3 --version` there). It defaults to `stable`.

## Lifecycle

```sh
bin/t3env up                       # create or resume the VM
bin/t3env connect                  # wait for cloud-init, then sign the VM into T3 Connect (URL + code, once per volume)
op read op://vault/claude/token | bin/t3env auth   # give the VM's T3 a Claude token, once per volume
bin/t3env down                     # delete the VM, keep volume, IP and key pair (stops compute billing)
bin/t3env destroy                  # delete everything, including the data volume
```

Make the token with `claude setup-token` on a machine with a browser. `auth` reads it from stdin, so it stays out of shell history, tfvars, user_data and Terraform state, and writes it to `~/.t3/provider.env` with mode 0600 on the volume.

After `connect`, link the VM from your local T3 Code in Settings > Environments > Linked environments, or with `t3 environment link <address> --pairing-code <code> --access <mode>`, taking the code from `t3 pair` on the VM.

After `down` and `up`, cloud-init reinstalls the T3 service from the volume's sign-in, so the VM comes back on the same T3 Connect address without `connect` or `auth`.

## Security

- Every process T3 starts inherits `CLAUDE_CODE_OAUTH_TOKEN`, including the builds and tests of the repos you delegate, and `ubuntu` is in the `docker` group. Run only repos you trust here, and revoke the token from your Claude account if the VM is compromised.
- `up` forgets the VM's SSH host key and trusts the first one it sees, because each new VM brings a new key on the same floating IP. Compare it with `openstack console log show` if the network path is not yours.

## Verified

On an existing Ubuntu 24.04 VM with T3 Code 0.1.7-nightly and cloud-init 26.1, set up by hand with the same files:

- cloud-init's own `mkfs` against a loop device: with `partition: none` a second instance erased the data, and with `partition: auto` the data survived.
- After `t3 service uninstall`, `t3 service install` from a non-login shell with `XDG_RUNTIME_DIR` set brought T3 Connect back on the same address with no `t3 up`.

- `t3 policy show` reports the policy loaded, and a laptop links the VM with no `settings.json` on it.
- The drop-in survives `t3 up --connect --yes`, and a variable in `provider.env` reaches the T3 server process and its children.
- The installer installs the nightly build when `T3CODE_CHANNEL=nightly` is in its environment.
- With only `CLAUDE_CODE_OAUTH_TOKEN` in `provider.env` (`claude auth status` on the VM still says `loggedIn: false`), the VM's Claude provider reports it can run tasks, and a task delegated from the laptop ran `hostname` on the VM.

## Not verified yet

- Flavor `csa.xlarge.v2` and zone `NCP-BKK` come from NIPA's public pages, not from the API.
- No `plan` or `apply` has run against NIPA, because the `ncp-devops` credential returns 401.
- `up` right after `down` can fail while Cinder still reports the volume as detaching. Wait a minute and rerun.
- T3 Connect's first reachability check right after `t3 up` reported `dns_failed` once, then passed on rerun.
