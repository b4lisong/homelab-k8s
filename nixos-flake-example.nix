# NixOS Flake Configuration Example for Flux GitOps
#
# This example shows how to declaratively configure your NixOS system
# to include the necessary tools for Flux GitOps management.
#
# Add this to your existing NixOS flake configuration.

{
  description = "NixOS configuration with Flux GitOps support";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      # Replace 'hostname' with your actual hostname
      hostname = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ pkgs, ... }: {
            # Install Flux and Kubernetes tools
            environment.systemPackages = with pkgs; [
              # GitOps tools
              fluxcd          # Flux CLI for GitOps
              kubectl         # Kubernetes CLI
              kubernetes-helm # Helm (optional, if you use it)

              # Additional useful tools
              k9s            # Kubernetes TUI (optional)
              kubecolor      # Colorized kubectl output (optional)
            ];

            # If running Kubernetes on this host, you might want:
            # services.k3s.enable = true;
            # OR
            # services.kubernetes = { ... };
          })
        ];
      };
    };
  };
}

# INTEGRATION EXAMPLES:

# Example 1: Minimal addition to existing flake
# Add to your existing configuration.nix or in a module:
#
# { pkgs, ... }: {
#   environment.systemPackages = with pkgs; [
#     fluxcd
#     kubectl
#   ];
# }

# Example 2: If you use home-manager
# Add to home.nix or home-manager module:
#
# { pkgs, ... }: {
#   home.packages = with pkgs; [
#     fluxcd
#     kubectl
#   ];
# }

# Example 3: With environment variables (for GitHub token)
# Add to your configuration:
#
# { pkgs, ... }: {
#   environment.systemPackages = with pkgs; [ fluxcd kubectl ];
#
#   # Set environment variables system-wide (not recommended for secrets)
#   # Instead, use a shell script or direnv for secrets
#   environment.variables = {
#     GITHUB_USER = "your-username";
#   };
#
#   # For secrets, use agenix, sops-nix, or environment files:
#   # environment.etc."flux-secrets".text = ''
#   #   GITHUB_TOKEN=your-token-here
#   # '';
# }

# Example 4: Kubernetes cluster on NixOS with k3s
#
# { pkgs, ... }: {
#   environment.systemPackages = with pkgs; [ fluxcd kubectl ];
#
#   services.k3s = {
#     enable = true;
#     role = "server";
#     extraFlags = toString [
#       "--write-kubeconfig-mode=644"
#       "--cluster-init"
#     ];
#   };
#
#   # Set kubeconfig for kubectl
#   environment.variables = {
#     KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
#   };
# }

# REBUILD COMMANDS:
#
# After modifying your flake:
# sudo nixos-rebuild switch --flake .#
#
# Or for a specific host:
# sudo nixos-rebuild switch --flake .#hostname
#
# Test without activating:
# sudo nixos-rebuild test --flake .#

# VERIFICATION:
#
# After rebuild, verify installation:
# flux --version
# kubectl version --client
