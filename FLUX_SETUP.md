# Flux GitOps Setup Instructions

## Prerequisites

1. **Kubernetes cluster** named 'bh' must be running and accessible
2. **kubectl** configured with access to the cluster
3. **GitHub personal access token** with repo permissions

## Step 1: Install Flux CLI (NixOS)

### Option A: Declarative Installation (Recommended)

Add to your NixOS flake configuration:

```nix
{
  environment.systemPackages = with pkgs; [
    fluxcd
    kubectl
  ];
}
```

Then rebuild:
```bash
sudo nixos-rebuild switch --flake .#
```

### Option B: Temporary Shell (for testing)

```bash
nix shell nixpkgs#fluxcd nixpkgs#kubectl
```

### Option C: User Profile

```bash
nix profile install nixpkgs#fluxcd
```

Verify installation:
```bash
flux --version
```

## Step 2: Export GitHub Credentials

Replace `<your-username>` and `<your-token>` with your actual values:

```bash
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=<your-username>
export GITHUB_REPO=homelab-k8s
```

## Step 3: Pre-flight Check

Verify your cluster is ready for Flux:

```bash
flux check --pre
```

This should show all checks passing.

## Step 4: Bootstrap Flux

Bootstrap Flux into your cluster. This will:
- Install Flux controllers in the `flux-system` namespace
- Create a GitRepository resource pointing to this repo
- Commit the Flux manifests to `clusters/bh/flux-system/`
- Set up reconciliation

```bash
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/bh \
  --personal \
  --context=bh
```

**Note**: If your kubeconfig context has a different name, replace `bh` in `--context=bh` with your actual context name.

## Step 5: Verify Installation

Check that Flux is running:

```bash
# Check all Flux components
flux check

# View installed controllers
kubectl get pods -n flux-system

# Check GitRepository sync status
flux get sources git

# Check Kustomizations
flux get kustomizations
```

You should see:
- `flux-system` - The main GitRepository (reconciling every 1m)
- `infrastructure` - Infrastructure components (reconciling every 10m)
- `apps` - Application deployments (reconciling every 5m)

## Step 6: Verify Homepage Deployment

```bash
# Check Homepage namespace and pods
kubectl get pods -n homepage

# View Homepage service
kubectl get svc -n homepage

# Check ingress
kubectl get ingress -n homepage
```

## Step 7: Verify Image Automation

Check that image automation is working:

```bash
# View image repositories
flux get image repository

# View image policies
flux get image policy

# View image update automation
flux get image update
```

The `homepage` ImageRepository should be scanning for new tags.

## Step 8: Monitor Flux

Watch Flux logs in real-time:

```bash
# All Flux logs
flux logs --all-namespaces --follow

# Specific controller logs
flux logs --kind=Kustomization --name=apps
flux logs --kind=ImageRepository --name=homepage
```

## Step 9: Test Reconciliation

Make a change to trigger reconciliation:

```bash
# Force immediate reconciliation of apps
flux reconcile kustomization apps --with-source

# Watch the reconciliation
kubectl get pods -n homepage --watch
```

## Step 10: Delete Old k8s Directory (After Validation)

Once everything is working correctly:

```bash
# From repository root
git rm -r k8s/
git commit -m "Remove old k8s directory - migrated to Flux structure"
git push
```

Flux will automatically detect the commit and reconcile the cluster state.

## How GitOps Works Now

### Making Changes

1. **Edit files locally** in `apps/` or `infrastructure/`
2. **Commit and push** to GitHub
3. **Flux automatically detects** the change within 1 minute (GitRepository interval)
4. **Flux applies changes** to the cluster within 5-10 minutes (Kustomization intervals)

### Image Updates

1. **New Homepage version released** (e.g., v1.6.0)
2. **ImageRepository scans** and detects new tag within 1 minute
3. **ImagePolicy evaluates** if it matches semver range (1.x.x)
4. **ImageUpdateAutomation updates** the deployment YAML
5. **Commits and pushes** to GitHub automatically
6. **Flux reconciles** the new image to the cluster

### Rollback

```bash
# Option 1: Git revert
git revert <commit-hash>
git push

# Option 2: Suspend and resume
flux suspend kustomization apps
# Fix the issue manually or in Git
flux resume kustomization apps
```

## Troubleshooting

### Check reconciliation status
```bash
flux get all
```

### View detailed status
```bash
kubectl describe kustomization apps -n flux-system
kubectl describe gitrepository flux-system -n flux-system
```

### Force reconciliation
```bash
flux reconcile source git flux-system
flux reconcile kustomization infrastructure
flux reconcile kustomization apps
```

### Image automation not working
```bash
# Check ImageRepository status
kubectl describe imagerepository homepage -n flux-system

# Check ImagePolicy status
kubectl describe imagepolicy homepage -n flux-system

# Verify marker in deployment
grep imagepolicy apps/homepage/deployment.yaml
```

## Directory Structure Reference

```
.
├── clusters/bh/
│   ├── flux-system/              # Auto-generated by Flux
│   ├── infrastructure.yaml       # Infrastructure Kustomization
│   ├── apps.yaml                 # Apps Kustomization
│   ├── image-repository.yaml     # Homepage image scanning
│   ├── image-policy.yaml         # Homepage version policy
│   └── image-update-automation.yaml  # Auto-update configuration
│
├── infrastructure/
│   ├── kustomization.yaml
│   └── traefik/
│       ├── kustomization.yaml
│       └── middleware-headers.yaml
│
└── apps/
    ├── kustomization.yaml
    └── homepage/
        ├── kustomization.yaml
        ├── namespace.yaml
        ├── serviceaccount.yaml
        ├── clusterrole.yaml
        ├── clusterrolebinding.yaml
        ├── configmap.yaml
        ├── deployment.yaml       # Contains image policy marker
        ├── service.yaml
        └── ingress.yaml
```

## Success Criteria

✅ All Flux controllers running in `flux-system` namespace
✅ GitRepository syncing successfully
✅ Infrastructure Kustomization reconciled
✅ Apps Kustomization reconciled
✅ Homepage pod running in `homepage` namespace
✅ ImageRepository scanning for new tags
✅ Homepage accessible via ingress
✅ Changes pushed to Git automatically applied to cluster

## Next Steps

- Add more applications to `apps/`
- Add infrastructure components to `infrastructure/`
- Configure notifications (Slack, Discord, etc.)
- Set up multi-cluster or multi-environment deployments
- Configure SOPS for secrets encryption
