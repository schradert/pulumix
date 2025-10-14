{
  buildGoModule,
  fetchFromGitHub,
  gnumake,
}:
buildGoModule rec {
  pname = "pulumi-terraform-provider";
  version = "3.114.0";
  meta.mainProgram = "terraform-provider";

  src = fetchFromGitHub {
    owner = "pulumi";
    repo = "pulumi-terraform-bridge";
    rev = "v${version}";
    hash = "sha256-nQ4PX+ADmU/aFPZ+S1TV9vzgPh9EkRRnkA+TIEZHSFw=";
  };
  vendorHash = "sha256-mSUe5DVh0cSjBPgCQiSNsm8AN6A5446xJciEjedde1s=";

  nativeBuildInputs = [gnumake];
  buildPhase = ''
    runHook preBuild
    VERSION=${version} make -C dynamic build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp dynamic/bin/* $out/bin/
    runHook postInstall
  '';
}