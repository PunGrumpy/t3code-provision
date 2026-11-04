# t3code-provision

Terraform for one cloud VM that runs T3 Code as a linked environment, so agents on your laptop can delegate builds and tests to it.

## Layout

- `modules/bootstrap` renders the cloud-init every cloud shares. Its one cloud-specific input is the data volume's `/dev/disk/by-*` path inside the guest.
- `clouds/<name>` is one Terraform root per provider: the VM, a persistent data volume, a key pair and an SSH-only firewall. NIPA keeps one floating IP; Hetzner and AWS give the VM a new public IP on each `up`. `clouds/nipa` is NIPA Cloud on OpenStack, `clouds/hetzner` is Hetzner Cloud and `clouds/aws` is EC2 in the default VPC.
- The cloud-init mounts the volume at `/srv/t3`, links `~/.t3`, `~/.claude`, `~/.codex`, `~/.config/gh` and `~/workspace` into it, installs `t3`, Claude Code and Docker, and writes the two files below.
- `/etc/t3code/policy.json` is a T3 Code managed policy that turns on Linked environments. Without it the VM refuses every link until someone flips Settings > Labs for it.
- `~/.config/systemd/user/t3code.service.d/provider-env.conf` loads `~/.t3/provider.env` into the T3 service. `t3 up` rewrites the service unit, so the credentials ride in a drop-in instead.
- `bin/t3env` wraps the lifecycle.

## Prerequisites

Every cloud needs `clouds/<name>/terraform.tfvars`, copied from its example, and `t3_channel` set to the release train of the machine you link from (`t3 --version` there). It defaults to `stable`.

For `clouds/nipa`:

- A working `ncp-devops` entry in `~/.config/openstack/clouds.yaml` with its application credential in `secure.yaml`. Terraform reads it through `cloud = "ncp-devops"`, so no secret goes into tfvars or state. Check it with `OS_CLOUD=ncp-devops openstack token issue`.
- `clouds/nipa/terraform.tfvars`, copied from the example, with real image, network and floating IP pool names from `openstack image list`, `openstack network list` and `openstack network list --external`.

For `clouds/hetzner`:

- `HCLOUD_TOKEN` exported from a read-write API token of the project.
- A `server_type` sold in your `location` (default `sin`), from `hcloud server-type list`.
- Your public key not already uploaded to the project. Hetzner refuses a second key with the same fingerprint, so delete the old one or point `ssh_public_key_path` at another key.

For `clouds/aws`:

- AWS credentials in the usual chain (`AWS_PROFILE`, `aws sso login` or env) and a default VPC in `region`.
- A Nitro `instance_type` (the default `t3.xlarge` is one). cloud-init finds the data volume by its NVMe serial, which older Xen types do not expose.

## Lifecycle

```sh
bin/t3env nipa up                       # create or resume the VM
bin/t3env nipa connect                  # wait for cloud-init, then sign the VM into T3 Connect (URL + code; rerun after `up` if the VM is unreachable)
op read op://vault/claude/token | bin/t3env nipa auth   # give the VM's T3 a Claude token, once per volume
bin/t3env nipa down                     # delete the VM, keep volume, IP and key pair (stops compute billing)
bin/t3env nipa destroy                  # delete everything, including the data volume
```

Make the token with `claude setup-token` on a machine with a browser. `auth` reads it from stdin, so it stays out of shell history, tfvars, user_data and Terraform state, and writes it to `~/.t3/provider.env` with mode 0600 on the volume.

After `connect`, link the VM from your local T3 Code in Settings > Environments > Linked environments, or with `t3 environment link <address> --pairing-code <code> --access <mode>`, taking the code from `t3 pair` on the VM.

After `down` and `up`, cloud-init reinstalls the T3 service from the volume's sign-in. The VM should come back on the same T3 Connect address without `connect` or `auth`, but that is only tested on the same machine (see below).

## Security

- Every process T3 starts inherits `CLAUDE_CODE_OAUTH_TOKEN`, including the builds and tests of the repos you delegate, and `ubuntu` is in the `docker` group. Run only repos you trust here, and revoke the token from your Claude account if the VM is compromised.
- `up` forgets the VM's SSH host key and trusts the first one it sees, because each new VM brings a new key. Compare it with the console log (`openstack console log show`, `hcloud server request-console`, `aws ec2 get-console-output`) if the network path is not yours.

## Tests

`terraform test` in `modules/bootstrap` checks that the cloud-init is valid YAML with a valid policy JSON, formats only the disk it was given, and keeps `partition: auto`. Each cloud's `tests/` runs the root against a mock provider and checks the device path cloud-init receives. CI runs `fmt`, `validate` and `test` for every directory under `modules/` and `clouds/`.

## Verified

On an existing Ubuntu 24.04 VM with T3 Code 0.1.7-nightly and cloud-init 26.1, set up by hand with the same files:

- cloud-init's own `mkfs` against a loop device: with `partition: none` a second instance erased the data, and with `partition: auto` the data survived.
- A user manager started before `usermod -aG` keeps the old group list, and `systemctl restart user@<uid>.service` picks up the new group, checked with `systemd-run --user id -Gn`.
- After `t3 service uninstall`, `t3 service install` from a non-login shell with `XDG_RUNTIME_DIR` set brought T3 Connect back on the same address with no `t3 up`.

- `t3 policy show` reports the policy loaded, and a laptop links the VM with no `settings.json` on it.
- The drop-in survives `t3 up --connect --yes`, and a variable in `provider.env` reaches the T3 server process and its children.
- The installer installs the nightly build when `T3CODE_CHANNEL=nightly` is in its environment.
- With only `CLAUDE_CODE_OAUTH_TOKEN` in `provider.env` (`claude auth status` on the VM still says `loggedIn: false`), the VM's Claude provider reports it can run tasks, and a task delegated from the laptop ran `hostname` on the VM.

## Not verified yet

- A recreated VM reusing the volume's T3 Connect sign-in. The test reinstalled the service on the same machine, with the same machine-id and host key.
- `clouds/hetzner` and `clouds/aws` have passed `validate` and their mock-provider tests only. No server has been created on either.
- On Hetzner and AWS the public IP changes on every `up`. T3 Connect does not care, and `up` resets the SSH host key file.
- That Hetzner's image accepts the explicit `ubuntu` user. Check `/home/ubuntu/.ssh/authorized_keys` on the first `up`.
- Flavor `csa.xlarge.v2` and zone `NCP-BKK` come from NIPA's public pages, not from the API.
- No `plan` or `apply` has run against NIPA, because the `ncp-devops` credential returns 401.
- `up` right after `down` can fail while Cinder still reports the volume as detaching. Wait a minute and rerun.
- T3 Connect's first reachability check right after `t3 up` reported `dns_failed` once, then passed on rerun.
