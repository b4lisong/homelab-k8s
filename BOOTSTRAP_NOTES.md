# Bootstrap Notes & Troubleshooting

## Bootstrap Order

Flux bootstrap happens in stages:

### Stage 1: Core Controllers (Bootstrap Command)
```bash
flux bootstrap git --url=ssh://git@github.com/... --path=./clusters/bh
```

**Installs:**
- source-controller (GitRepository)
- kustomize-controller (Kustomization)
- helm-controller (HelmRelease)
- notification-controller (Alerts)

**Does NOT install:**
- image-reflector-controller
- image-automation-controller

### Stage 2: Image Automation (GitOps Deployed)

After bootstrap completes, Flux deploys `infrastructure/flux-image-automation/`:
- Installs image-reflector-controller
- Installs image-automation-controller
- Then applies ImageRepository, ImagePolicy, ImageUpdateAutomation

**This is why image automation resources are in `infrastructure/`, not `clusters/bh/`**

## Common Bootstrap Errors

### Error: "no matches for kind ImagePolicy"

**Problem:** Image automation resources deployed before controllers installed

**Solution:** Image automation resources moved to `infrastructure/flux-image-automation/`
- Bootstrap installs core Flux
- Infrastructure Kustomization installs image automation controllers
- Then image automation resources can be applied

### Error: "kustomization not ready"

**Cause:** Dependency order issue

**Fix:** Check that:
```yaml
# clusters/bh/apps.yaml
spec:
  dependsOn:
    - name: infrastructure  # Apps wait for infrastructure
```

## Alternative: Bootstrap with Image Automation

If you want image automation immediately:

```bash
flux bootstrap git \
  --url=ssh://git@github.com/YOUR-USERNAME/homelab-k8s \
  --branch=main \
  --path=./clusters/bh \
  --private-key-file=~/.ssh/flux-homelab-bh \
  --components-extra=image-reflector-controller,image-automation-controller
```

**Trade-off:** Controllers installed imperatively, not managed by GitOps

## Verification Commands

```bash
# Check all controllers are running
flux check

# View all Flux components
kubectl get pods -n flux-system

# Check Kustomizations
flux get kustomizations

# Check image automation (after infrastructure deploys)
flux get image repository
flux get image policy
flux get image update

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
  ├─ Traefik middleware deployed
  └─ Image automation controllers deployed
      ↓
      Image automation resources deployed (ImageRepository, ImagePolicy, etc.)
  ↓
Kustomization 'apps' reconciles (depends on infrastructure)
  ↓
Homepage deployed with image policy marker
  ↓
ImageUpdateAutomation starts monitoring for new versions
```

## Why This Approach?

✅ **Fully GitOps** - Image automation controllers managed by Git
✅ **Declarative** - Everything in repository, reproducible
✅ **Dependency management** - Infrastructure deploys before apps
✅ **No manual steps** - Bootstrap + push = complete system

## Rollback

If bootstrap fails:

```bash
# Uninstall Flux
flux uninstall --namespace=flux-system

# Fix repository

# Re-bootstrap
flux bootstrap git ...
```
