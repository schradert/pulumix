{
  lib,
  mkPulumiPackage,
  fetchFromGitHub,
  runCommand,
}: let
  cmdGen = "pulumi-tfgen-aws";
  version = "7.8.0";
  owner = "pulumi";
  repo = "pulumi-aws";
  rev = "v${version}";
  hash = "sha256-Tj2xZ1OyzFKwC2eJIeD/UsE++4cDZDjlR1+3xUGFLqE=";
  fetchSubmodules = true;
  # upstream patches must be used in all derivations
  src = runCommand "source-${repo}-${rev}" {
    src = fetchFromGitHub {inherit owner repo rev hash fetchSubmodules;};
  } ''
    cp -r $src $out
    chmod -R +w $out
    cd $out/upstream
    for patch_file in ../patches/*.patch; do
      patch -p1 < "$patch_file"
    done
  '';
in (mkPulumiPackage rec {
  inherit owner repo rev hash fetchSubmodules src version cmdGen;
  vendorHash = "sha256-VoVWVyUm+zKNPns2+2jIY3Pffg1yB9tzRZ2AWbonVEY=";
  cmdRes = "pulumi-resource-aws";
  extraLdflags = ["-X github.com/${owner}/${repo}/provider/pkg/version.Version=${rev}"];
  __darwinAllowLocalNetworking = true;
  meta.mainProgram = cmdRes;
}).overrideAttrs (old: rec {
  # pulumi-gen
  nativeBuildInputs = lib.forEach old.nativeBuildInputs (drv:
    if drv.pname == cmdGen
    then drv.overrideAttrs (_: {inherit src;})
    else drv
  );
  # python SDK
  passthru = old.passthru // {
    sdks.python = old.passthru.sdks.python.overrideAttrs (_: {inherit src;});
  };
})
