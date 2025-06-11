{
  inputs.nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
  inputs.opentofu-registry.url = "github:opentofu/registry";
  inputs.opentofu-registry.flake = false;
  outputs = {nixpkgs, opentofu-registry, self, ...}: let
    pkgs = import nixpkgs {
      system = "aarch64-darwin";
      overlays = [
        (final: prev: {
          pulumiPackages = prev.pulumiPackages.overrideScope (pFinal: pPrev: {
            pulumi-yaml = final.callPackage ({
              buildGoModule,
              fetchFromGitHub, 
            }: buildGoModule rec {
              pname = "pulumi-yaml";
              version = "1.19.0";

              src = fetchFromGitHub {
                owner = "pulumi";
                repo = "pulumi-yaml";
                tag = "v${version}";
                hash = "sha256-2RRr05yrNWd1zePzgIl2ZS0yZ0t6gRkAM9qh4HlSeVI=";
              };
              vendorHash = "sha256-3jj8LQz1pq24YTw5uawWvpDGSkBtGeCqGAS2AvFPTUc=";
              
              # TODO don't skip every test
              doCheck = false;
            }) {};
            mkOpenTofuProvider = provider: let
              inherit (prev.lib) elemAt substring importJSON length head filter splitString;
              inherit (prev.go) GOARCH GOOS;

              # Parse source (e.g. "owner/repo[/versionTry]")
              providerParts = splitString "/" provider;
              owner = elemAt providerParts 0;
              repo = elemAt providerParts 1;
              source = "${owner}/${repo}";

              # Target system version (latest by default)
              version = let
                upstreamOwner =
                  if owner == "hashicorp"
                  then "opentofu"
                  else owner;
                file = opentofu-registry + "/providers/${substring 0 1 upstreamOwner}/${upstreamOwner}/${repo}.json";
                inherit (importJSON file) versions;
                hasSpecificVersion = (length providerParts) == 3;
                specificVersion = head (filter (v: v.version == elemAt providerParts 2) versions);
                latestVersion = head versions;
              in
                if hasSpecificVersion then specificVersion else latestVersion;
              target = head (filter (t: t.arch == GOARCH && t.os == GOOS) version.targets);
            in pkgs.stdenv.mkDerivation {
              inherit (version) version;
              pname = "terraform-provider-${repo}";
              src = pkgs.fetchurl {
                url = target.download_url;
                sha256 = target.shasum;
              };
              unpackPhase = "unzip -o $src";
              nativeBuildInputs = [pkgs.unzip];
              buildPhase = ":";
              installPhase = "cp terraform-* $out/";
              passthru = {inherit repo source;};           
            };
          }); 
        }) 
      ];
    };
    project = (pkgs.formats.yaml {}).generate "Pulumi.yaml" {
      name = "main";
      runtime = "yaml";
      backend.url = "file://.pulumix";
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
    packages.aarch64-darwin.terraform-provider-headscale = pkgs.pulumiPackages.mkOpenTofuProvider "awlsring/headscale";
    apps.aarch64-darwin.default = {
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
}
