# Bootstrap Notes & Troubleshooting

## Bootstrap Order

Flux bootstrap is simple - it installs core controllers:

### Bootstrap Command
```bash
flux bootstrap git --url=ssh://git@github.com/... --path=./clusters/bh
```

**Installs:**
- source-controller (GitRepository)
- kustomize-controller (Kustomization)
- helm-controller (HelmRelease)
- notification-controller (Alerts)

**That's it!** No extra controllers needed for basic GitOps.

### After Bootstrap

Flux reads your Git repository and deploys:
1. `infrastructure/` - Infrastructure components (Traefik, etc.)
2. `apps/` - Applications (Homepage, etc.)

## Image Automation (Optional - Not Included)

This setup uses **manual version updates** for simplicity:
- Edit deployment YAML to change image tags
- Commit and push
- Flux deploys the update

**To add automatic image updates later**, you'd need:
- image-reflector-controller
- image-automation-controller
- ImageRepository, ImagePolicy, ImageUpdateAutomation resources

Not included by default - adds complexity without much benefit for homelab learning.

## Common Bootstrap Errors

### Error: "no matches for kind ImagePolicy"

**Problem:** Image automation resources deployed without controllers

**Solution:** Image automation removed from this setup - not needed for basic GitOps

### Error: "kustomization not ready"

**Cause:** Dependency order issue

**Fix:** Check that:
```yaml
# clusters/bh/apps.yaml
spec:
  dependsOn:
    - name: infrastructure  # Apps wait for infrastructure
```

## Adding Image Automation Later (Optional)

If you want automatic image updates in the future:

1. Bootstrap with extra controllers:
```bash
flux bootstrap git \
  --url=ssh://git@github.com/YOUR-USERNAME/homelab-k8s \
  --branch=main \
  --path=./clusters/bh \
  --private-key-file=~/.ssh/flux-homelab-bh \
  --components-extra=image-reflector-controller,image-automation-controller
```

2. Add ImageRepository, ImagePolicy, ImageUpdateAutomation resources to your repo
3. Add image policy markers to deployment YAMLs

**For learning:** Start simple, add this later when comfortable with Flux basics

## Verification Commands

```bash
# Check all controllers are running
flux check

# View all Flux components
kubectl get pods -n flux-system

# Check Kustomizations
flux get kustomizations

# View application status
kubectl get pods -n homepage

# Force reconciliation
flux reconcile kustomization infrastructure --with-source
flux reconcile kustomization apps --with-source
```

## Current Architecture

```
Bootstrap (SSH)
  ↓
Core Flux Controllers Installed
  ↓
GitRepository 'flux-system' created
  ↓
Kustomization 'infrastructure' reconciles
  ↓
Traefik middleware deployed
  ↓
Kustomization 'apps' reconciles (depends on infrastructure)
  ↓
Homepage deployed (fixed version v1.5.0)
  ↓
Git = Source of Truth
(edit YAML → commit → push → Flux deploys)
```

## Why This Approach?

✅ **Simple** - Core GitOps without extra controllers
✅ **Declarative** - Everything in repository, reproducible
✅ **Dependency management** - Infrastructure deploys before apps
✅ **No manual steps** - Bootstrap + push = complete system
✅ **Learning-focused** - Master basics before adding automation

## Rollback

If bootstrap fails:

```bash
# Uninstall Flux
flux uninstall --namespace=flux-system

# Fix repository

# Re-bootstrap
flux bootstrap git ...
```
