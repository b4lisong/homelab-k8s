# Cloudflare Tunnel

## Prerequisites

Create the token secret manually (once):

```bash
kubectl create secret generic cloudflared-token \
  --from-literal=token="YOUR_TUNNEL_TOKEN" \
  --namespace=cloudflare
```

Get your token from: Cloudflare Dashboard → Zero Trust → Networks → Tunnels → Configure
```

**Step 3c: Deploy via Flux**

```bash
# Add to infrastructure kustomization
# Edit infrastructure/kustomization.yaml and add:
#   - cloudflare-tunnel

# Commit to Git
git add infrastructure/cloudflare-tunnel/
git commit -m "Add Cloudflare Tunnel via Flux"
git push

# Flux will deploy automatically, or force reconciliation:
flux reconcile kustomization infrastructure --with-source
```
