{config, lib, pkgs, ...}: {
  options.pulumix.build = {
    yamlPackage = (pkgs.formats.yaml {}).generate "Pulumi.yaml" config.pulumi;
    cliPackage = pkgs.writeShellApplication {
      name = "pulumix-${config.pulumi.name}";
      runtimeEnv.PULUMI_DISABLE_AUTOMATIC_PLUGIN_ACQUISITION = true;
      runtimeInputs = [
        (pkgs.pulumi.withPackages (ps: with ps; [
          pulumi-yaml
          pulumi-hcloud
        ]))
      ];
      text = ''
        tmp="$(mktemp -d)"
        trap 'popd; rm -rf "$tmp"' EXIT
        pushd "$tmp"
        cp ${config.pulumix.build.yamlPackage} Pulumi.yaml
        pulumi "$@"
      '';
    };
  };
}
