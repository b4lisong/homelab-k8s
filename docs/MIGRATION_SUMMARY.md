# Flux Migration Summary

## What Changed

### New Structure Created
```
clusters/bh/                      # Flux cluster configuration
├── apps.yaml                     # Kustomization: deploys apps/
├── infrastructure.yaml           # Kustomization: deploys infrastructure/
├── image-repository.yaml         # Scans ghcr.io/gethomepage/homepage
├── image-policy.yaml            # Selects versions matching 1.x.x
└── image-update-automation.yaml  # Auto-commits image updates

apps/                             # Application deployments
├── kustomization.yaml
└── homepage/                     # Moved from k8s/base/homepage/
    ├── deployment.yaml          # Updated with image policy marker
    └── [all other manifests]

infrastructure/                   # Infrastructure components
├── kustomization.yaml
└── traefik/                     # Moved from k8s/base/traefik/
    ├── kustomization.yaml
    └── middleware-headers.yaml
```

### Key Changes

1. **Homepage deployment.yaml** (apps/homepage/deployment.yaml:19)
   - Fixed version: `image: ghcr.io/gethomepage/homepage:v1.5.0`
   - Update manually when you want to upgrade

2. **Old k8s/ directory** - Keep until verified, then delete

3. **Simple GitOps workflow**
   - Edit manifests → Commit → Push → Flux deploys
   - No automatic image updates (keep it simple for learning)

## What Flux Will Do

### Reconciliation Intervals
- **GitRepository**: Pulls from GitHub every 1 minute
- **Infrastructure**: Reconciles every 10 minutes
- **Apps**: Reconciles every 5 minutes (after infrastructure is ready)

### Manual Update Flow (When You Want to Upgrade)
1. Edit `apps/homepage/deployment.yaml` - change image tag to new version
2. Commit: `git commit -m "upgrade homepage to v1.6.0"`
3. Push: `git push`
4. Flux detects commit (within 1 min)
5. Flux reconciles new version to cluster (within 5 min)

## Next Steps (NixOS)

1. **Add fluxcd to your NixOS flake** (see nixos-flake-example.nix)
   ```nix
   environment.systemPackages = with pkgs; [ fluxcd kubectl ];
   ```
   ```bash
   sudo nixos-rebuild switch --flake .#
   ```

2. **Setup SSH Deploy Key** (on remote NixOS system)
   ```bash
   ssh-keygen -t ed25519 -C "flux-homelab-bh" -f ~/.ssh/flux-homelab-bh
   cat ~/.ssh/flux-homelab-bh.pub
   # Add to GitHub: Settings → Deploy keys (enable write access)
   ```

3. **Bootstrap Flux** with SSH authentication
   ```bash
   flux bootstrap git \
     --url=ssh://git@github.com/YOUR-USERNAME/homelab-k8s \
     --branch=main \
     --path=./clusters/bh \
     --private-key-file=~/.ssh/flux-homelab-bh
   ```

4. **Verify** all resources are deployed correctly
   ```bash
   flux get all
   kubectl get pods -n homepage
   ```

5. **Test** image automation by checking for auto-updates

6. **Delete** k8s/ directory once validated:
   ```bash
   git rm -r k8s/
   git commit -m "Remove old k8s directory"
   git push
   ```

## Rollback Plan

If something goes wrong:

```bash
# Suspend Flux
flux suspend kustomization apps
flux suspend kustomization infrastructure

# Apply old manifests manually
kubectl apply -k k8s/

# Or revert the Git commit
git revert HEAD
git push
```

## Configuration Files

- **FLUX_SETUP.md** - Complete bootstrap and setup instructions
- **clusters/bh/** - All Flux resources for 'bh' cluster
- **apps/** - Application deployments (Homepage, etc.)
- **infrastructure/** - Infrastructure components (Traefik, etc.)
