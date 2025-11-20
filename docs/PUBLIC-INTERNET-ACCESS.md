# Public Internet Access Guide

Complete guide for exposing your homelab Kubernetes services to the public internet using Cloudflare Tunnel, without port forwarding.

## Table of Contents

- [Overview](#overview)
- [Why Expose Authelia Publicly?](#why-expose-authelia-publicly)
- [Cloudflare Tunnel vs Alternatives](#cloudflare-tunnel-vs-alternatives)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Setup Guide](#setup-guide)
- [Configuration](#configuration)
- [Security Hardening](#security-hardening)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## Overview

This guide shows how to expose your homelab services (Silverbullet, Authelia, etc.) to the public internet using **Cloudflare Tunnel**, maintaining your existing local access while adding secure remote access.

### What You'll Get

- ✅ Public internet access via custom domain
- ✅ No port forwarding required
- ✅ DDoS protection included
- ✅ Free tier (unlimited tunnels)
- ✅ Local access still works
- ✅ Works with existing Traefik + Authelia setup

---

## Why Expose Authelia Publicly?

### The Problem

When accessing services from the public internet, the authentication redirect fails:

```
User (Internet) → https://sb.yourdomain.com
  ↓ (needs auth)
Traefik redirects → https://auth.bh.zz
  ↓
❌ FAILS - Browser can't reach auth.bh.zz (local DNS only)
```

### The Solution

Expose both the service AND Authelia:

```
User (Internet) → https://sb.yourdomain.com
  ↓ (needs auth)
Traefik redirects → https://auth.yourdomain.com
  ↓
✅ SUCCESS - User can login via public auth portal
  ↓
Redirected back to → https://sb.yourdomain.com (authenticated)
```

**Key point:** Authentication flow requires the auth portal to be accessible from wherever the user is accessing the protected service.

---

## Cloudflare Tunnel vs Alternatives

### Comparison Table

| Feature | Cloudflare Tunnel | Tailscale Funnel | Port Forward | Reverse Proxy VPS |
|---------|------------------|------------------|--------------|-------------------|
| **Cost** | Free | $6/user for custom domain | Free | $3-5/month |
| **Setup Complexity** | Medium | Low | Low | High |
| **DDoS Protection** | Yes | No | No | Limited |
| **Custom Domain** | Yes (free) | Yes (paid) | Yes | Yes |
| **Port Forwarding** | Not needed | Not needed | Required | Not needed |
| **CDN Benefits** | Yes | No | No | No |
| **Privacy** | Routes via Cloudflare | Private WireGuard | Direct | Routes via VPS |
| **Bandwidth Limits** | None | Yes (free tier) | ISP dependent | VPS limits |
| **WebSocket Support** | Yes | Yes | Yes | Yes |

### Recommendation: Cloudflare Tunnel

**Best for:**
- Public-facing services
- Custom domain (free)
- DDoS protection needs
- CDN/caching benefits
- Zero-trust security

**Use Tailscale instead if:**
- Privacy is top priority
- Only personal/team access needed
- Don't want Cloudflare dependency

**Hybrid approach (Best):**
- Cloudflare Tunnel for public access
- Tailscale for private admin access
- Both are free!

---

## Architecture

### Current Setup (Local Only)

```
┌─────────────────┐
│  Local Network  │
│                 │
│  sb.bh.zz      │──┐
│  auth.bh.zz    │  │
└─────────────────┘  │
                     ▼
              ┌──────────────┐
              │   Traefik    │
              │  (Ingress)   │
              └──────────────┘
                     │
        ┌────────────┼────────────┐
        ▼                         ▼
  ┌──────────┐            ┌──────────┐
  │Authelia  │            │Silverbullet│
  │  (Auth)  │            │  (App)    │
  └──────────┘            └──────────┘
```

### With Cloudflare Tunnel (Dual Access)

```
┌──────────────────────────────────────────┐
│            Public Internet               │
│                                          │
│  sb.yourdomain.com                      │
│  auth.yourdomain.com                    │
└────────────┬─────────────────────────────┘
             │
             ▼
      ┌─────────────┐
      │ Cloudflare  │
      │   (CDN +    │
      │   Tunnel)   │
      └─────────────┘
             │
             │ Encrypted Tunnel
             │ (Outbound HTTPS)
             ▼
┌─────────────────────────────────────────┐
│         Local Network (NAT)             │
│                                         │
│  ┌──────────────┐                      │
│  │  cloudflared │                      │
│  │   (Tunnel)   │                      │
│  └──────┬───────┘                      │
│         │                               │
│         ▼                               │
│  ┌──────────────┐                      │
│  │   Traefik    │                      │
│  │  (Ingress)   │◄─── Local: sb.bh.zz │
│  └──────────────┘     auth.bh.zz      │
│         │                               │
│  ┌──────┴───────┐                      │
│  ▼              ▼                       │
│ Authelia    Silverbullet                │
└─────────────────────────────────────────┘
```

**Key Benefits:**
- Both local and public access work simultaneously
- No changes to existing local configuration
- Cloudflare provides security layer

---

## Prerequisites

### 1. Domain Name
- Custom domain (e.g., `yourdomain.com`)
- Can be from any registrar
- Will transfer DNS to Cloudflare (free)

### 2. Cloudflare Account
- Free tier is sufficient
- Sign up at https://dash.cloudflare.com/sign-up

### 3. Current Setup Requirements
- Kubernetes cluster (k3s) ✅
- Traefik ingress controller ✅
- cert-manager installed ✅
- Authelia deployed ✅
- Services working locally ✅

---

## Setup Guide

### Step 1: Add Domain to Cloudflare

1. **Login to Cloudflare Dashboard**
   - Go to https://dash.cloudflare.com/

2. **Add Site**
   - Click "Add a Site"
   - Enter your domain: `yourdomain.com`
   - Select Free plan

3. **Update Nameservers**
   - Cloudflare shows 2 nameservers
   - Go to your domain registrar
   - Replace nameservers with Cloudflare's
   - Wait for propagation (5 min - 24 hours)

### Step 2: Create Cloudflare Tunnel

1. **Navigate to Tunnels**
   - Dashboard → Zero Trust → Access → Tunnels
   - Click "Create a tunnel"

2. **Name Your Tunnel**
   - Name: `homelab-k8s` (or your preference)
   - Save tunnel

3. **Copy Tunnel Token**
   - Copy the token shown (starts with `eyJ...`)
   - You'll need this for Kubernetes deployment

### Step 3: Deploy Cloudflared in Kubernetes

**Method 1: Using Helm (Recommended)**

```bash
# Add Cloudflare Helm repo
helm repo add cloudflare https://cloudflare.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace cloudflare

# Create secret with tunnel token
kubectl create secret generic tunnel-credentials \
  --from-literal=credentials.json='{"AccountTag":"YOUR_ACCOUNT_ID","TunnelSecret":"YOUR_SECRET","TunnelID":"YOUR_TUNNEL_ID"}' \
  --namespace=cloudflare

# Install cloudflared
helm install cloudflared cloudflare/cloudflared \
  --namespace cloudflare \
  --set cloudflare.tunnelName=homelab-k8s \
  --set cloudflare.token=YOUR_TUNNEL_TOKEN
```

**Method 2: Using Kubernetes Manifests**

Create `infrastructure/cloudflare-tunnel/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflare
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
        - tunnel
        - --no-autoupdate
        - run
        - --token
        - YOUR_TUNNEL_TOKEN
        livenessProbe:
          httpGet:
            path: /ready
            port: 2000
          failureThreshold: 1
          initialDelaySeconds: 10
          periodSeconds: 10
```

Apply:
```bash
kubectl create namespace cloudflare
kubectl apply -f infrastructure/cloudflare-tunnel/
```

### Step 4: Configure Tunnel Routes

In Cloudflare Dashboard → Tunnels → Your Tunnel → Public Hostname:

**Route 1: Silverbullet**
- Subdomain: `sb`
- Domain: `yourdomain.com`
- Path: (leave empty)
- Service Type: `HTTP`
- URL: `traefik.kube-system.svc.cluster.local:80`

**Route 2: Authelia**
- Subdomain: `auth`
- Domain: `yourdomain.com`
- Path: (leave empty)
- Service Type: `HTTP`
- URL: `traefik.kube-system.svc.cluster.local:80`

**Note:** If your Traefik is in a different namespace, adjust the service URL.

### Step 5: Create Public Ingresses

**Authelia External Ingress:**

Create `infrastructure/authelia/ingress-external.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: authelia-external
  namespace: authelia
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - auth.yourdomain.com
    secretName: authelia-external-tls
  rules:
  - host: auth.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: authelia-svc
            port:
              number: 80
```

**Silverbullet External Ingress:**

Create `apps/silverbullet/ingress-external.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: silverbullet-external
  namespace: silverbullet
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.middlewares: authelia-authelia-forwardauth@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - sb.yourdomain.com
    secretName: silverbullet-external-tls
  rules:
  - host: sb.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: silverbullet
            port:
              number: 80
```

Add to kustomization:
```yaml
# apps/silverbullet/kustomization.yaml
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - ingress-external.yaml  # ADD THIS
```

### Step 6: Update Authelia Configuration

Edit `infrastructure/authelia/configuration.yaml`:

```yaml
session:
  secret: insecure_session_secret
  cookies:
    # Local network cookie
    - name: authelia_session_local
      domain: bh.zz
      authelia_url: https://auth.bh.zz
      default_redirection_url: https://sb.bh.zz
      expiration: 1h
      inactivity: 5m
      remember_me: 1M

    # Public internet cookie
    - name: authelia_session_public
      domain: yourdomain.com
      authelia_url: https://auth.yourdomain.com
      default_redirection_url: https://sb.yourdomain.com
      expiration: 1h
      inactivity: 5m
      remember_me: 1M
```

Apply changes:
```bash
kubectl apply -f infrastructure/authelia/configuration.yaml
kubectl rollout restart deployment/authelia -n authelia
```

### Step 7: Update cert-manager ClusterIssuer Email

Edit `infrastructure/cert-manager/clusterissuers.yaml`:

```yaml
spec:
  acme:
    email: your-real-email@example.com  # UPDATE THIS
```

Apply:
```bash
kubectl apply -f infrastructure/cert-manager/clusterissuers.yaml
```

---

## Configuration

### Cloudflare Dashboard Settings

#### SSL/TLS

Navigate to: SSL/TLS → Overview

- **SSL/TLS encryption mode:** Full (strict)
  - Validates origin certificates from cert-manager

#### Network

Navigate to: Network

- **WebSockets:** ON
  - Required for Silverbullet real-time sync
- **HTTP/2:** ON (default)
- **HTTP/3 (QUIC):** ON (optional, improves performance)

#### Page Rules (Free: 3 rules)

Navigate to: Rules → Page Rules

**Rule 1: Bypass API cache**
```
URL: *sb.yourdomain.com/api/*
Settings:
  - Cache Level: Bypass
```

**Rule 2: Bypass service worker cache**
```
URL: *sb.yourdomain.com/sw.js
Settings:
  - Cache Level: Bypass
```

**Rule 3: Cache static assets**
```
URL: *sb.yourdomain.com/*.{js,css,woff2,png,jpg,svg}
Settings:
  - Cache Level: Standard
  - Edge Cache TTL: 1 month
```

#### Security Settings (Optional Hardening)

Navigate to: Security → Settings

- **Security Level:** Medium (or High for maximum protection)
- **Challenge Passage:** 30 minutes
- **Browser Integrity Check:** ON

#### Firewall Rules (Optional)

Navigate to: Security → WAF

Create rule to rate-limit login attempts:

```
Expression: (http.request.uri.path contains "/api/firstfactor") and (http.request.method eq "POST")
Action: Challenge
Rate limit: 5 requests per minute
```

---

## Security Hardening

### 1. Strong Authentication

Already configured:
- ✅ Argon2id password hashing
- ✅ Secure session management
- ✅ HTTPS only (cert-manager)

### 2. Rate Limiting

**Cloudflare (Automatic):**
- DDoS protection included
- Automatic challenge for suspicious traffic

**Authelia (Built-in):**
Edit `infrastructure/authelia/configuration.yaml`:

```yaml
regulation:
  max_retries: 3
  find_time: 2m
  ban_time: 5m
```

### 3. Geo-Blocking (Optional)

If you only need access from specific countries:

Cloudflare → Security → WAF → Create Firewall Rule:
```
Expression: (ip.geoip.country ne "US" and ip.geoip.country ne "CA")
Action: Block
```

### 4. IP Allowlist (Optional)

If you have known IPs:

```
Expression: (http.host eq "auth.yourdomain.com" and ip.src ne YOUR_IP)
Action: Challenge
```

### 5. Cloudflare Access (Advanced)

Add an additional authentication layer BEFORE Authelia:

- Navigate to: Zero Trust → Access → Applications
- Create application for `auth.yourdomain.com`
- Require email domain or specific users
- Adds SSO layer (Google, GitHub, etc.)

**Flow with Cloudflare Access:**
```
User → Cloudflare Access (Google login) → Authelia (password) → Service
```

### 6. Monitoring & Alerts

**Cloudflare Analytics:**
- Dashboard → Analytics → Traffic
- Monitor requests, bandwidth, threats blocked

**Authelia Logs:**
```bash
kubectl logs -n authelia -l app=authelia -f
```

Watch for:
- Failed login attempts
- Suspicious IP addresses
- Configuration errors

---

## Testing

### Pre-Flight Checks

```bash
# 1. Verify cloudflared is running
kubectl get pods -n cloudflare
# Should show 2 pods running

# 2. Check tunnel status
# In Cloudflare Dashboard → Tunnels
# Status should be "Healthy"

# 3. Verify cert-manager issued certificates
kubectl get certificate -n authelia
kubectl get certificate -n silverbullet
# Should show "Ready" status

# 4. Check Authelia is running
kubectl get pods -n authelia
# Should show 1/1 Running
```

### External Access Testing

**Test 1: Authelia Login Page**
```bash
# From external network (or use phone data)
curl -I https://auth.yourdomain.com

# Expected: HTTP/200, CF headers present
# CF-Cache-Status: DYNAMIC (not cached)
# CF-RAY: (Cloudflare ray ID)
```

**Test 2: Silverbullet Redirect**
```bash
# Access Silverbullet without auth
curl -I https://sb.yourdomain.com

# Expected: HTTP/302 redirect to auth.yourdomain.com
```

**Test 3: Full Authentication Flow**

1. Open browser (incognito mode)
2. Navigate to: `https://sb.yourdomain.com`
3. Should redirect to: `https://auth.yourdomain.com`
4. Login with credentials
5. Should redirect back to: `https://sb.yourdomain.com`
6. Silverbullet loads successfully

**Test 4: Local Access Still Works**

On local network:
1. Navigate to: `https://sb.bh.zz`
2. Should redirect to: `https://auth.bh.zz`
3. Login with same credentials
4. Silverbullet loads successfully

**Test 5: PWA Functionality**

1. Access: `https://sb.yourdomain.com`
2. Open DevTools → Application → Service Workers
3. Service worker should be registered
4. Enable offline mode in DevTools
5. Reload page - should load from cache
6. Create a note - should save locally
7. Re-enable network - should sync

**Test 6: WebSocket Real-Time Sync**

1. Open two browser windows
2. Both at: `https://sb.yourdomain.com`
3. Edit in window 1
4. Changes should appear in window 2 immediately

### Performance Testing

```bash
# Test latency
curl -w "@curl-format.txt" -o /dev/null -s https://sb.yourdomain.com

# curl-format.txt content:
time_namelookup: %{time_namelookup}s
time_connect: %{time_connect}s
time_appconnect: %{time_appconnect}s
time_pretransfer: %{time_pretransfer}s
time_redirect: %{time_redirect}s
time_starttransfer: %{time_starttransfer}s
time_total: %{time_total}s
```

Expected latency:
- DNS lookup: <50ms
- Connect: <100ms
- Total: <500ms (varies by location)

### Cache Testing

```bash
# Test static asset caching
curl -I https://sb.yourdomain.com/main.js

# First request: CF-Cache-Status: MISS
# Second request: CF-Cache-Status: HIT
```

---

## Troubleshooting

### Issue: "Tunnel Not Connecting"

**Symptoms:**
- Cloudflare Dashboard shows tunnel offline
- `cloudflared` pods crash looping

**Solutions:**
```bash
# Check pod logs
kubectl logs -n cloudflare -l app=cloudflared

# Common issues:
# 1. Invalid token
kubectl get secret tunnel-credentials -n cloudflare -o yaml
# Verify token is correct

# 2. Network issues
kubectl exec -n cloudflare deployment/cloudflared -- ping 1.1.1.1
# Should succeed

# 3. Restart deployment
kubectl rollout restart deployment/cloudflared -n cloudflare
```

### Issue: "Certificate Not Issuing"

**Symptoms:**
- Ingress shows no certificate
- cert-manager challenges failing

**Solutions:**
```bash
# Check certificate status
kubectl describe certificate -n authelia authelia-external-tls

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Common issues:
# 1. DNS not propagated
dig auth.yourdomain.com
# Should return Cloudflare IPs

# 2. HTTP01 challenge blocked
# Ensure Page Rules don't block /.well-known/acme-challenge/

# 3. Switch to DNS01 challenge (advanced)
# Requires Cloudflare API token
```

### Issue: "Redirect Loop"

**Symptoms:**
- Browser shows "Too many redirects"
- Never reaches login page

**Solutions:**
```bash
# Check Authelia logs
kubectl logs -n authelia -l app=authelia | grep -i redirect

# Common causes:
# 1. Session cookie domain mismatch
# Edit configuration.yaml, ensure domain matches

# 2. Cloudflare SSL mode wrong
# Set to "Full (strict)" not "Flexible"

# 3. Clear browser cookies
# Delete all cookies for yourdomain.com
```

### Issue: "Auth Works But Service 404"

**Symptoms:**
- Login successful
- Redirected back but service shows 404

**Solutions:**
```bash
# Check if service ingress exists
kubectl get ingress -n silverbullet

# Verify host matches in ingress
kubectl get ingress silverbullet-external -n silverbullet -o yaml | grep host

# Check Traefik is routing correctly
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik | grep yourdomain.com
```

### Issue: "Slow Performance"

**Symptoms:**
- Pages load slowly
- High latency

**Solutions:**
1. **Enable HTTP/2 & HTTP/3** in Cloudflare → Network
2. **Optimize Page Rules** - ensure static assets cached
3. **Check tunnel health** - multiple replicas?
   ```bash
   kubectl scale deployment/cloudflared -n cloudflare --replicas=3
   ```
4. **Use Argo Smart Routing** (paid, but faster)

### Issue: "WebSockets Not Working"

**Symptoms:**
- Real-time sync fails
- Silverbullet shows offline

**Solutions:**
1. **Enable WebSockets** in Cloudflare → Network
2. **Check connection in DevTools:**
   - Console should show WebSocket connected
   - Network tab shows WS connection (101 status)
3. **Verify Traefik passes WebSocket:**
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=traefik | grep upgrade
   ```

---

## Additional Resources

### Cloudflare Documentation
- [Tunnel Setup](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Page Rules](https://developers.cloudflare.com/rules/page-rules/)
- [SSL/TLS Settings](https://developers.cloudflare.com/ssl/)

### Authelia Documentation
- [Configuration](https://www.authelia.com/configuration/prologue/introduction/)
- [Session Cookies](https://www.authelia.com/configuration/session/introduction/)

### Troubleshooting Tools
```bash
# DNS propagation check
dig auth.yourdomain.com +short

# SSL certificate check
openssl s_client -connect auth.yourdomain.com:443 -servername auth.yourdomain.com

# Check Cloudflare routing
curl -I https://auth.yourdomain.com | grep CF

# Trace request through stack
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=100 | grep yourdomain
```

---

## Summary Checklist

Before going live:

- [ ] Domain added to Cloudflare
- [ ] Nameservers updated and propagated
- [ ] Cloudflare Tunnel created and token saved
- [ ] `cloudflared` deployed to Kubernetes
- [ ] Tunnel routes configured (sb + auth subdomains)
- [ ] External ingresses created for both services
- [ ] Authelia configuration updated with public domain
- [ ] cert-manager email updated in ClusterIssuer
- [ ] Cloudflare SSL mode set to "Full (strict)"
- [ ] WebSockets enabled in Cloudflare
- [ ] Page Rules configured for PWA compatibility
- [ ] Certificates issued successfully
- [ ] Local access still works (sb.bh.zz)
- [ ] Public access works (sb.yourdomain.com)
- [ ] Authentication flow tested end-to-end
- [ ] PWA offline mode tested
- [ ] WebSocket real-time sync tested
- [ ] Security hardening configured (rate limits, etc.)
- [ ] Monitoring enabled

**You're live!** Your homelab is now accessible from anywhere with enterprise-grade security.
