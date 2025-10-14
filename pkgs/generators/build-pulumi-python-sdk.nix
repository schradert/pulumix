{
  stdenv,
  pulumi-cli,
  terraform-providers,
  buildPythonPackage,
  go,
  setuptools,
  pulumi,
  parver,
  semver,
}:
provider:
buildPythonPackage rec {
  pname = "pulumi-${src.pname}";
  inherit (src) version;

  pyproject = true;
  src = stdenv.mkDerivation rec {
    pname = provider;
    inherit (src) version;

    src = terraform-providers.${provider}.overrideAttrs (old: {
      # Name of binary run by terraform-provider cannot have trailing version
      postInstall = old.postInstall + ''
        mv $dir/${old.passthru.repo}_${old.version} $dir/${old.passthru.repo}
      '';
    });

    nativeBuildInputs = [
      (pulumi-cli.withPackages (ps: with ps; [pulumi-python pulumi-terraform-provider]))
    ];
    # Must set user to something to avoid error in os.Current
    buildPhase = ''
      USER=1 pulumi package gen-sdk --language python terraform-provider \
        ./libexec/terraform-providers/${src.provider-source-address}/${version}/${go.GOOS}_${go.GOARCH}/${src.repo}
    '';
    installPhase = ''
      mkdir -p $out
      cp -r sdk/python/* $out/
    '';
  };

  build-system = [setuptools];
  propagatedBuildInputs = [
    parver
    pulumi
    semver
  ];
}
