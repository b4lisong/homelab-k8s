# Secrets Management with Flux

## The Problem

By default, `flux bootstrap github` stores your GitHub token as a Kubernetes Secret in **base64** (not encrypted). Anyone with cluster access can decode it.

## Recommended Solution for Public Repos: SSH Deploy Keys

**For public repositories (like this homelab), use SSH deploy keys instead of tokens.**

### Why SSH Deploy Keys?

✅ **No token needed** - Uses SSH key authentication
✅ **Repository-scoped** - Key only works for this one repo
✅ **Simpler** - No encryption tooling needed
✅ **Safe for public repos** - Private key stays in cluster/host only

### Setup (Already in FLUX_SETUP.md)

```bash
# Generate key
ssh-keygen -t ed25519 -C "flux-homelab-bh" -f ~/.ssh/flux-homelab-bh

# Add public key to GitHub as Deploy Key (with write access)
cat ~/.ssh/flux-homelab-bh.pub

# Bootstrap with SSH
flux bootstrap git \
  --url=ssh://git@github.com/YOUR-USERNAME/homelab-k8s \
  --branch=main \
  --path=./clusters/bh \
  --private-key-file=~/.ssh/flux-homelab-bh
```

The private key is stored as a K8s Secret - acceptable for a homelab cluster you control.

---

## Advanced Options (For App Secrets & Multi-Cluster)

When you need to store **application secrets** (API keys, database passwords) in Git, consider these:

### Option 1: SOPS with Age (Recommended for Secrets in Git)

Mozilla SOPS encrypts secrets in Git, Flux decrypts them in-cluster.

#### Setup on NixOS

1. **Add to your flake:**
   ```nix
   {
     environment.systemPackages = with pkgs; [
       fluxcd
       kubectl
       sops          # Secret encryption
       age           # Encryption key management
     ];
   }
   ```

2. **Generate Age key:**
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   # Note the public key: age1...
   ```

3. **Create `.sops.yaml` in repo root:**
   ```yaml
   creation_rules:
     - path_regex: .*.yaml
       encrypted_regex: ^(data|stringData)$
       age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p  # Your public key
   ```

4. **Create encrypted secret:**
   ```bash
   # Create secret file
   cat <<EOF > clusters/bh/flux-system-secret.yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: flux-system
     namespace: flux-system
   stringData:
     username: your-github-username
     password: ghp_yourGitHubToken
   EOF

   # Encrypt it with SOPS
   sops --encrypt --in-place clusters/bh/flux-system-secret.yaml
   ```

5. **Create SOPS decryption secret in cluster:**
   ```bash
   # Import Age private key to cluster
   cat ~/.config/sops/age/keys.txt | \
   kubectl create secret generic sops-age \
     --namespace=flux-system \
     --from-file=age.agekey=/dev/stdin
   ```

6. **Configure Flux to use SOPS:**
   ```yaml
   # clusters/bh/kustomization.yaml (in flux-system/)
   apiVersion: kustomize.toolkit.fluxcd.io/v1
   kind: Kustomization
   metadata:
     name: flux-system
     namespace: flux-system
   spec:
     interval: 10m0s
     path: ./clusters/bh
     prune: true
     sourceRef:
       kind: GitRepository
       name: flux-system
     decryption:
       provider: sops
       secretRef:
         name: sops-age
   ```

Now your GitHub token is **encrypted in Git**, only decrypted in the cluster!

### Option 2: Agenix (NixOS Native)

If you're already using Agenix for NixOS secrets:

1. **Add GitHub token to Agenix:**
   ```nix
   # secrets/flux-github-token.age
   age.secrets.flux-github-token = {
     file = ./secrets/flux-github-token.age;
     owner = "root";
   };
   ```

2. **Mount secret in Kubernetes manifest:**
   ```bash
   # Create Kubernetes secret from Agenix-decrypted file
   kubectl create secret generic flux-system \
     --from-file=password=/run/agenix/flux-github-token \
     --from-literal=username=your-github-username \
     --namespace=flux-system
   ```

3. **Automate with systemd service:**
   ```nix
   systemd.services.flux-secret-sync = {
     description = "Sync Flux GitHub token from Agenix to Kubernetes";
     after = [ "k3s.service" "agenix.service" ];
     wantedBy = [ "multi-user.target" ];
     serviceConfig = {
       Type = "oneshot";
       ExecStart = pkgs.writeShellScript "sync-flux-secret" ''
         ${pkgs.kubectl}/bin/kubectl create secret generic flux-system \
           --from-file=password=/run/agenix/flux-github-token \
           --from-literal=username=your-github-username \
           --namespace=flux-system \
           --dry-run=client -o yaml | ${pkgs.kubectl}/bin/kubectl apply -f -
       '';
     };
   };
   ```

### Option 3: Sealed Secrets (Alternative)

Bitnami Sealed Secrets encrypt secrets that only the cluster can decrypt:

```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install kubeseal CLI (NixOS)
nix profile install nixpkgs#kubeseal

# Create sealed secret
kubectl create secret generic flux-system \
  --from-literal=username=your-user \
  --from-literal=password=ghp_token \
  --namespace=flux-system \
  --dry-run=client -o yaml | \
kubeseal -o yaml > clusters/bh/flux-system-sealed.yaml

# Commit sealed secret (safe to push to public repo!)
git add clusters/bh/flux-system-sealed.yaml
git commit -m "Add encrypted Flux credentials"
```

## Comparison

| Method | Use Case | Encryption | Complexity | Multi-cluster |
|--------|----------|-----------|------------|---------------|
| **SSH Deploy Key** | ⭐ Flux authentication | ❌ No token needed | Very Low | ✅ Yes |
| **SOPS + Age** | App secrets in Git | ✅ In Git | Medium | ✅ Yes |
| **Agenix** | NixOS-native secrets | ✅ In Git | Low (if using) | ✅ Yes |
| **Sealed Secrets** | Cluster-specific secrets | ✅ Cluster-only | Medium | ❌ Per-cluster |

## Recommended Approach

### For Flux Authentication (This Repo)
→ **SSH Deploy Key** (already documented in FLUX_SETUP.md)
- ✅ Public repo safe
- ✅ Single cluster homelab
- ✅ No encryption complexity needed

### For Application Secrets (Future)
→ **SOPS + Age** when you need to store API keys, passwords, etc. in Git
- Industry standard for GitOps
- Flux has native support
- Encrypted secrets safe in public repos

## Current State (After SSH Bootstrap)

Your SSH private key is stored as a Kubernetes Secret:
```bash
# View secret (contains SSH private key, base64 encoded)
kubectl get secret flux-system -n flux-system -o yaml
```

For a **homelab cluster you control**, this is acceptable. The deploy key is:
- ✅ Scoped to only this repository
- ✅ Stored securely in the cluster
- ✅ Not exposed in Git (public repo safe)

### Optional: Backup Your SSH Key

```bash
# Backup the private key (store securely!)
cp ~/.ssh/flux-homelab-bh ~/.ssh/flux-homelab-bh.backup
chmod 400 ~/.ssh/flux-homelab-bh.backup

# If you lose the cluster, you'll need this to re-bootstrap
```
