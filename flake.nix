{
  description = "Manage Pulumi stacks with Nix";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} ({lib, ...}: {
    imports = [inputs.devenv.flakeModule];
    systems = ["x86_64-linux" "aarch64-darwin" "aarch64-linux"];
    flake.overlays.default = ./pkgs;
    perSystem = {lib, pkgs, self', system, ...}: {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [inputs.self.overlays.default];
      };
      legacyPackages = pkgs.pulumiPackages;
      packages = lib.filterAttrs (_: lib.isDerivation) self'.legacyPackages; 
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
      };
    };
  });
}
