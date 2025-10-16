{pkgs, ...}: {
  overlays = [(import ./pkgs)];
  packages = [
    (pkgs.pulumi.withPackages (ps: with ps; [
      pulumi-yaml
      # pulumi-aws
      # pulumi-cloudflare
      # pulumi-github
      # pulumi-googleworkspace
      # pulumi-headscale
    ]))
  ];
}
