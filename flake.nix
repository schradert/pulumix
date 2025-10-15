{
  description = "Manage Pulumi stacks with Nix";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} ({lib, ...}: {
    imports = [inputs.devenv.flakeModule];
    systems = ["x86_64-linux" "aarch64-darwin" "aarch64-linux"];
    flake.overlays.default = ./pkgs;
    perSystem = {pkgs, system, ...}: {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [inputs.self.overlays.default];
      };
      packages = legacyPackages.pulumiPackages;
      legacyPackages = {
        inherit (pkgs) pulumiPackages;
        pulumiProject = {
          modules,
          pkgs ? pkgs,
        }: let
          _pkgs = pkgs.extend inputs.self.overlays.default;
        in _pkgs.lib.evalModules {
          modules = modules ++ [./pulumi.nix ./pulumix.nix];
          specialArgs = {
            pkgs = _pkgs;
            inherit (_pkgs) lib;
          };
        };
      };
      packages = {
        inherit (pkgs.pulumiPackages)
          pulumi-aws
          pulumi-cloudflare
          pulumi-github
          pulumi-googleworkspace
          pulumi-headscale;
      };
      apps.aarch64-darwin.default = let
        project = (pkgs.formats.yaml {}).generate "Pulumi.yaml" {
          name = "main";
          runtime = "yaml";
          packages = {
            hcloud.source = "${pkgs.pulumiPackages.pulumi-hcloud}/bin";
            hcloud.version = pkgs.pulumiPackages.pulumi-hcloud.version;
          };
          plugins.languages = pkgs.lib.toList {
            name = "yaml";
            path = "${pkgs.pulumiPackages.pulumi-yaml}/bin";
            version = pkgs.pulumiPackages.pulumi-yaml.version; 
          };
          config."hcloud:token".value = "ref+sops://${./sops.yaml}#/hetzner/token+";
          variables.ip."fn::invoke" = {
            function = "hcloud:getPrimaryIp";
            arguments.name = "root";
          };
          resources.key = {
            type = "hcloud:SshKey";
            properties.name = "my-ssh-key";
            properties.publicKey = pkgs.lib.fileContents ./tristan.pub;
          };
          outputs.ip = "\${ip.ipAddress}";
        };
      in {
        type = "app";
        program = pkgs.lib.getExe (pkgs.writeShellApplication {
          name = "pulumi";
          runtimeEnv = {
            PULUMI_DISABLE_AUTOMATIC_PLUGIN_ACQUISITION = true;
            PULUMI_HOME = ".pulumi";
            PULUMI_STACK = "prod";
          };
          runtimeInputs = with pkgs; [pulumi vals];
          text = ''
            vals eval -s -f ${project} > Pulumi.yaml
            trap 'rm -f Pulumi.yaml' EXIT

            PULUMI_CONFIG_PASSPHRASE="$(vals get 'ref+sops://${./sops.yaml}#/pulumi/passphrase+' 2>/dev/null)"
            export PULUMI_CONFIG_PASSPHRASE

            pulumi stack select "$PULUMI_STACK" --create
            pulumi "$@"
          '';
        });
      };
    };
  });
}
