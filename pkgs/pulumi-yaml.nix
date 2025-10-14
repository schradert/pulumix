{
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
}
