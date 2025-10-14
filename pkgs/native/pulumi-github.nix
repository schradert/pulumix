{
  lib,
  mkPulumiPackage,
}:
mkPulumiPackage rec {
  owner = "pulumi";
  repo = "pulumi-github";
  version = "6.7.3";
  rev = "v${version}";
  hash = "sha256-89iEi2mcBJYJxPvsoXvuRI7ob7aKeJbI3LcvFMIknlU=";
  vendorHash = "sha256-Fp3fGc8gPjBLh+vZdact5BhVaKBq5BvDFx2lTXBvG9o=";
  cmdGen = "pulumi-tfgen-github";
  cmdRes = "pulumi-resource-github";
  fetchSubmodules = true;
  extraLdflags = ["-X github.com/${owner}/${repo}/provider/pkg/version.Version=${version}"];
  __darwinAllowLocalNetworking = true;
  meta.mainProgram = cmdRes;
}
