{
  inputs.pulumix.url = "github:schradert/pulumix";
  outputs = inputs: inputs.pulumix.inputs.flake-parts.lib.mkFlake {inherit inputs;} {
    systems = inputs.pulumix.inputs.nixpkgs.lib.flakeExposed;
    perSystem = {inputs', lib, ...}: {
      packages.default = inputs'.pulumix.legacyPackages.buildPulumiProject {
        modules = [
          ({pulumix, ...}: {
            configs.hcloud.token = "ref+sops://${./sops.yaml}#/hetzner/token+";
            variables.ip = pulumix.hcloud.getPrimaryIp {name = "root";};
            resources.hcloud.SshKey.my-ssh-key.publicKey = lib.fileContents ./me.pub;
            outputs.ip = "\${ip.ipAddress}";
          })
        ];
      };
    };
  };
}
