{
  mkPulumiPackage,
}:
mkPulumiPackage rec {
  owner = "schradert";
  repo = "pulumi-headscale";
  version = "0.0.1";
  rev = "main";
  hash = "sha256-XHLNqSX+xDe5q0TfFN+NQEQWmV9fwRmy2kmQ6bVCKmI=";
  vendorHash = "sha256-vLTIal7skmaOq5a9jheP44BsTnwMnLz4rP2HAFlcle0=";
  cmdGen = "pulumi-tfgen-headscale";
  cmdRes = "pulumi-resource-headscale";
  env.GOWORK = "off";
  extraLdflags = ["-X github.com/${owner}/${repo}/provider/pkg/version.Version=${version}"];
  __darwinAllowLocalNetworking = true;
  meta.mainProgram = cmdRes;
}
