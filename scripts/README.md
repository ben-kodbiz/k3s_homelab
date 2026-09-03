# Scripts

## Preflight

```bash
./scripts/preflight.sh
```

Read-only host discovery and KVM/libvirt verification. Creates baseline in `artifacts/host-network-before/`.

## Host Network Check

```bash
./scripts/host-network-check.sh baseline   # snapshot current state
./scripts/host-network-check.sh compare    # compare vs baseline; FAIL on drift
```

## Validate

```bash
./scripts/validate.sh        # run all gates
./scripts/validate.sh 4      # run up to gate 4
```

## Destroy

```bash
./scripts/destroy.sh                    # interactive
./scripts/destroy.sh --cluster cluster-a
./scripts/destroy.sh --all-resources
```

## Create/Delete VM

```bash
./scripts/create-vm.sh <name> <vcpu> <mem_mb> <network> <base_vol> <pool> <userdata> <netconfig> <pool_path> [disk_gb]
./scripts/delete-vm.sh <name> [pool]
```
