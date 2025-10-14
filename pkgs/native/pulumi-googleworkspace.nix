{
  mkPulumiPackage,
  lib,
}:
mkPulumiPackage rec {
  owner = "schradert";
  repo = "pulumi-googleworkspace";
  version = "0.0.1";
  rev = "main";
  hash = "sha256-DzR7S1AB8dFhQotfJwWWUyzxS3iNxAce2WzXQgtOiz4=";
  vendorHash = lib.fakeHash;
  cmdGen = "pulumi-tfgen-googleworkspace";
  cmdRes = "pulumi-resource-googleworkspace";
  env.GOWORK = "off";
  extraLdflags = ["-X github.com/${owner}/${repo}/provider/pkg/version.Version=${version}"];
  __darwinAllowLocalNetworking = true;
  meta.mainProgram = cmdRes;
}
