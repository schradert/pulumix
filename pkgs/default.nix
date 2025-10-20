final: prev: let
  inherit (final) lib;
  suboverlay = extensions: lib.flip lib.pipe [
    builtins.listToAttrs
    (set: _: _: set)
    lib.toList
    (lib.concat extensions)
  ];
in builtins.foldl' (acc: overlay: acc // (overlay final (prev // acc))) {} [
  (final: prev: {
    pulumiPackages = prev.pulumiPackages.overrideScope (_: _: {
      pulumi-yaml = final.callPackage ./pulumi-yaml.nix {};
      buildPulumiProject = {
        modules,
        pkgs ? final,
        lib ? pkgs.lib,
      }: pkgs.lib.evalModules {
        modules = modules ++ [../modules];
        specialArgs = {inherit pkgs lib;};
      };
    });
  })
  (final: prev: {
    pulumiPackages = prev.pulumiPackages.overrideScope (_: _: {
      pulumi-terraform-provider = final.callPackage ./pulumi-terraform-provider.nix {};
      buildPulumiPythonSDK = final.python3Packages.callPackage ./generators/build-pulumi-python-sdk.nix {pulumi-cli = final.pulumi;};
    });
    # pythonPackagesExtensions = lib.pipe [
    #   "googleworkspace"
    # ] [
    #   (map final.pulumiPackages.buildPulumiPythonSDK)
    #   (map (pkg: lib.nameValuePair pkg.pname pkg))
    #   (suboverlay prev.pythonPackagesExtensions)
    # ];
  })
  (final: prev: {
    pulumiPackages = prev.pulumiPackages.overrideScope (pFinal: _: {
      pulumi-cloudflare = pFinal.callPackage ./native/pulumi-cloudflare.nix {};
      pulumi-github = pFinal.callPackage ./native/pulumi-github.nix {};
      pulumi-googleworkspace = pFinal.callPackage ./native/pulumi-googleworkspace.nix {};
      pulumi-headscale = pFinal.callPackage ./native/pulumi-headscale.nix {};
      pulumi-aws = pFinal.callPackage ./native/pulumi-aws.nix {};
    });
    # TODO how are the modules upstream in nixpkgs passed automatically?
    # pythonPackagesExtensions = lib.pipe (with final.pulumiPackages; [
    #   pulumi-cloudflare
    #   pulumi-github
    # ]) [
    #   (map (pkg: lib.nameValuePair pkg.pname pkg.sdks.python))
    #   (suboverlay prev.pythonPackagesExtensions)
    # ];
  })
]
