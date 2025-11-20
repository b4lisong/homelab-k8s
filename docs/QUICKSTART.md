# Flux GitOps - Quick Start

## TL;DR - Get Flux Running in 5 Minutes

### 1. Install Flux CLI (NixOS)

**Declarative (recommended):**
```nix
# In your flake configuration
environment.systemPackages = with pkgs; [ fluxcd kubectl ];
```
```bash
sudo nixos-rebuild switch --flake .#
```

**Or temporary shell:**
```bash
nix shell nixpkgs#fluxcd nixpkgs#kubectl
flux --version
```

### 2. Setup SSH Deploy Key

**Generate SSH key:**
```bash
ssh-keygen -t ed25519 -C "flux-homelab-bh" -f ~/.ssh/flux-homelab-bh
# Press Enter for no passphrase (Flux needs passwordless access)
```

**Add to GitHub:**
```bash
# Display public key
cat ~/.ssh/flux-homelab-bh.pub

# Then go to: https://github.com/YOUR-USERNAME/homelab-k8s/settings/keys
# 1. Click "Add deploy key"
# 2. Title: "Flux GitOps - bh cluster"
# 3. Paste the public key
# 4. ✅ Check "Allow write access" (required for image automation)
```

### 3. Bootstrap Flux
```bash
flux bootstrap git \
  --url=ssh://git@github.com/YOUR-USERNAME/homelab-k8s \
  --branch=main \
  --path=./clusters/bh \
  --private-key-file=~/.ssh/flux-homelab-bh
```

### 4. Verify
```bash
# Check Flux is running
flux check

# Wait for infrastructure (including image automation controllers)
kubectl wait --for=condition=ready kustomization/infrastructure -n flux-system --timeout=5m

# Watch Homepage deployment
kubectl get pods -n homepage --watch
```

### 5. Done!
- Flux controllers installed
- Homepage should be running
- Git is now your source of truth

## What You Get

✅ **Automatic deployments** - Push to Git → Deployed in 1-10 minutes
✅ **Easy rollback** - Just `git revert` and push
✅ **Infrastructure as Code** - Everything in Git
✅ **Manual version control** - Update image tags when you want to upgrade

## Testing It Works

### Test Manual Change
```bash
# Edit something locally
vim apps/homepage/configmap.yaml

# Commit and push
git add apps/homepage/configmap.yaml
git commit -m "test: update homepage config"
git push

# Watch Flux apply it (within 5 minutes)
flux logs --kind=Kustomization --name=apps --follow
```

### Test Manual Update
```bash
# Check current version
kubectl get deployment homepage -n homepage -o jsonpath='{.spec.template.spec.containers[0].image}'

# To upgrade: edit apps/homepage/deployment.yaml, change image tag, commit and push
# Flux will deploy the new version automatically
```

## Troubleshooting One-Liners

```bash
# See everything Flux is doing
flux get all

# Force immediate sync
flux reconcile source git flux-system
flux reconcile kustomization apps --with-source

# View errors
flux logs --all-namespaces --level=error

# Suspend auto-updates (for maintenance)
flux suspend kustomization apps
# Resume when ready
flux resume kustomization apps
```

## Next Steps

- Read **FLUX_SETUP.md** for detailed documentation
- Read **MIGRATION_SUMMARY.md** to understand what changed
- Delete old `k8s/` directory after validating everything works
- Add more apps to `apps/` directory
- Enjoy GitOps!

## Directory Cheat Sheet

```
clusters/bh/        → Flux configuration (don't touch after bootstrap)
apps/              → Add your applications here
infrastructure/    → Add infrastructure components here (currently empty)
```

When you add something to `apps/` or `infrastructure/`, Flux automatically deploys it within 1-10 minutes.

## Next Steps

- Add more apps to `apps/` directory
- Install infrastructure (Traefik, cert-manager, etc.) when needed
- Explore Flux documentation for advanced features
