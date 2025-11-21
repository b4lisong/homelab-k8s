# Authelia Secrets Setup

**IMPORTANT:** These secrets must be created manually before deploying Authelia.
Do NOT commit these values to Git!

## Generate Random Secrets

```bash
# Generate three random secrets
JWT_SECRET=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 32)
ENCRYPTION_KEY=$(openssl rand -base64 32)

# Display them (save these somewhere safe!)
echo "JWT_SECRET: $JWT_SECRET"
echo "SESSION_SECRET: $SESSION_SECRET"
echo "ENCRYPTION_KEY: $ENCRYPTION_KEY"
```

## Create Kubernetes Secret

```bash
# Create the secret
kubectl create secret generic authelia-secrets \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --from-literal=session-secret="$SESSION_SECRET" \
  --from-literal=encryption-key="$ENCRYPTION_KEY" \
  --namespace=authelia

# Verify it was created
kubectl get secret authelia-secrets -n authelia
```

## After Creating the Secret

1. Deploy/update Authelia via Flux
2. Delete this guide file (it contains instructions but no actual secrets)
3. Keep your generated secrets somewhere safe (password manager) in case you need to recreate the secret

## Updating Secrets Later

```bash
# Delete old secret
kubectl delete secret authelia-secrets -n authelia

# Create new one with updated values
kubectl create secret generic authelia-secrets \
  --from-literal=jwt-secret="NEW_VALUE" \
  --from-literal=session-secret="NEW_VALUE" \
  --from-literal=encryption-key="NEW_VALUE" \
  --namespace=authelia

# Restart Authelia
kubectl rollout restart deployment/authelia -n authelia
```
