# Authelia Setup Guide

## Overview

Authelia is deployed as an authentication middleware for protecting services in your homelab Kubernetes cluster. It provides:
- Multi-factor authentication (TOTP + WebAuthn/Passkeys)
- Single Sign-On (SSO) across all protected services
- Centralized access control
- SQLite backend (lightweight, no external database)

## Secret Creation (Required Before Deployment)

The `authelia-users` Secret contains user credentials and **MUST be created manually** before deploying Authelia. This secret is NOT stored in Git to keep your public repository safe.

### Step 1: Generate Password Hash

Install the `apache2-utils` package (or use Docker) to generate bcrypt password hashes:

**Option A: Using Docker (recommended)**
```bash
docker run --rm authelia/authelia:4.38 authelia crypto hash generate argon2 --password 'YourPasswordHere'
```

**Option B: Using local installation**
```bash
# Install argon2 (macOS)
brew install argon2

# Generate hash
echo -n "YourPasswordHere" | argon2 somesalt -id -t 3 -m 16 -p 4 -l 32
```

The output will look like:
```
$argon2id$v=19$m=65536,t=3,p=4$randomsalt$randomhash
```

### Step 2: Create users_database.yml

Create a local file `users_database.yml`:

```yaml
users:
  admin:
    disabled: false
    displayname: "Admin User"
    password: "$argon2id$v=19$m=65536,t=3,p=4$..." # Paste your hash here
    email: admin@example.com
    groups:
      - admins
      - dev
```

**Important:**
- Replace the password hash with your generated hash
- Update the email address
- Add more users as needed (copy the block)

### Step 3: Create Kubernetes Secret

```bash
# Create the secret from file
kubectl create secret generic authelia-users \
  --from-file=users_database.yml=users_database.yml \
  --namespace=authelia

# Verify secret was created
kubectl get secret authelia-users -n authelia

# Delete the local file (security)
rm users_database.yml
```

### Step 4: Deploy via Flux

Once the secret exists, commit and push your Flux manifests:

```bash
git add infrastructure/ apps/
git commit -m "Add Authelia authentication middleware"
git push
```

Flux will deploy Authelia within 1-5 minutes.

## Accessing Authelia

### Login Portal
- URL: `https://auth.bh.zz`
- Username: `admin` (or whatever you configured)
- Password: (your password)

### First Login Flow

1. Navigate to `https://auth.bh.zz`
2. Enter username and password
3. Click "Register Security Key" or "Register One-Time Password"

#### TOTP Setup (Google Authenticator):
1. Scan the QR code with your authenticator app
2. Enter the 6-digit code to confirm

#### WebAuthn/Passkey Setup:
1. Click "Register Security Key"
2. Follow browser prompts (Touch ID, Face ID, Windows Hello, etc.)
3. Complete registration

### Testing Protected Access

After MFA enrollment:

1. Navigate to `https://sb.bh.zz`
2. You'll be redirected to Authelia login
3. Enter credentials + MFA
4. Redirected back to Silverbullet
5. Session valid for 1 hour (configurable)

## Configuration

### Access Control Rules

Edit `infrastructure/authelia/configuration.yaml` to modify access control:

```yaml
access_control:
  default_policy: deny
  rules:
    - domain: 'auth.bh.zz'
      policy: bypass  # Always allow access to login portal
    - domain: '*.bh.zz'
      policy: two_factor  # Require MFA for all services
    - domain: 'public.bh.zz'
      policy: bypass  # Example: bypass auth for specific service
```

Policies:
- `bypass`: No authentication required
- `one_factor`: Password only (no MFA)
- `two_factor`: Password + MFA required
- `deny`: Always deny access

### Session Duration

Edit `configuration.yaml`:

```yaml
session:
  cookies:
    - expiration: 1h  # Change session duration
      inactivity: 5m  # Auto-logout after inactivity
      remember_me: 1M  # "Remember me" duration
```

### Viewing and Modifying Users

**To view current users:**

```bash
# Get and decode the current secret
kubectl get secret authelia-users -n authelia -o jsonpath='{.data.users_database\.yml}' | base64 -d

# Or save to file for editing
kubectl get secret authelia-users -n authelia -o jsonpath='{.data.users_database\.yml}' | base64 -d > users_database.yml

# View the file
cat users_database.yml
```

**To add or modify users:**

1. Generate new password hash for new/changed passwords:

```bash
docker run --rm ghcr.io/authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'YourPassword'
```

2. Edit the users_database.yml file (add users, change passwords, etc.)

3. Update the secret:

```bash
kubectl create secret generic authelia-users \
  --from-file=users_database.yml=users_database.yml \
  --namespace=authelia \
  --dry-run=client -o yaml | kubectl apply -f -
```

4. Restart Authelia to pick up changes:

```bash
kubectl rollout restart deployment/authelia -n authelia
```

5. Clean up local file:

```bash
rm users_database.yml
```

## Protecting Additional Services

To protect any service with Authelia, add the middleware annotation to its ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: your-service
  namespace: your-namespace
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: authelia-authelia-forwardauth@kubernetescrd
spec:
  # ... rest of ingress config
```

## Troubleshooting

### Check Authelia Logs
```bash
kubectl logs -n authelia deployment/authelia -f
```

### Verify Middleware
```bash
kubectl get middleware -n authelia
```

### Test ForwardAuth Endpoint
```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://authelia.authelia.svc.cluster.local/api/authz/forward-auth
```

### Clear Session
Delete browser cookies for `.bh.zz` domain or use incognito mode.

## Security Notes

- Session secret and encryption key are placeholders in config (acceptable for local .bh.zz)
- User passwords are hashed with Argon2id (secure)
- MFA secrets stored encrypted in SQLite database
- SQLite database on emptyDir (lost on pod restart - acceptable for homelab)
- Optional: Add PersistentVolume for database persistence

## Upgrade Path

### To PostgreSQL Backend

When ready for multi-instance or persistence:

1. Deploy PostgreSQL
2. Update Authelia configuration
3. Migrate SQLite data (optional)

### To SOPS Secret Management

To maintain GitOps principles:

1. Install SOPS + age keys
2. Encrypt users_database.yml
3. Commit encrypted secret to Git
4. Configure Flux decryption

## Resources

- [Authelia Documentation](https://www.authelia.com/)
- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [WebAuthn Guide](https://webauthn.guide/)
