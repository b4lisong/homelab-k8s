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
   - Added image policy marker: `# {"$imagepolicy": "flux-system:homepage"}`
   - Enables automatic image updates

2. **Old k8s/ directory** - Keep until verified, then delete

3. **Image automation enabled**
   - Scans for new Homepage versions every 1 minute
   - Auto-updates to versions matching `1.x.x` pattern
   - Commits changes back to Git automatically

## What Flux Will Do

### Reconciliation Intervals
- **GitRepository**: Pulls from GitHub every 1 minute
- **Infrastructure**: Reconciles every 10 minutes
- **Apps**: Reconciles every 5 minutes (after infrastructure is ready)

### Image Automation Flow
1. New Homepage v1.6.0 released
2. ImageRepository detects it (within 1 min)
3. ImagePolicy approves it (matches 1.x.x)
4. ImageUpdateAutomation updates deployment.yaml
5. Commits: `[ci skip] Update image ghcr.io/gethomepage/homepage:v1.6.0`
6. Pushes to main branch
7. Flux reconciles new version to cluster (within 5 min)

## Next Steps (NixOS)

1. **Add fluxcd to your NixOS flake** (see nixos-flake-example.nix)
   ```nix
   environment.systemPackages = with pkgs; [ fluxcd kubectl ];
   ```
   ```bash
   sudo nixos-rebuild switch --flake .#
   ```

2. **Follow FLUX_SETUP.md** to bootstrap Flux on remote system

3. **Verify** all resources are deployed correctly

4. **Test** image automation by checking for auto-updates

5. **Delete** k8s/ directory once validated:
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
