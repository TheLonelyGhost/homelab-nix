{ pkgs }:

let
  version = "1.6.3";
  inherit (pkgs.lib) fakeSha256;
in
pkgs.buildGoModule {
  pname = "fabio";
  inherit version;

  src = pkgs.fetchFromGitHub {
    owner = "fabiolb";
    repo = "fabio";
    rev = "v${version}";
    sha256 = "sha256-xHrcVE1TrA6W8GavBd5LwloZt4g/qckdl8KvQyiH+Rc=";
  };

  nativeCheckInputs = [
    pkgs.vault
    pkgs.consul
  ];

  vendorHash = null;
  # vendorSha256 = fakeSha256;

  meta = {
    mainProgram = "fabio";
    homepage = "https://fabiolb.net/";
    description = "Consul Load-Balancing made simple";
    license = pkgs.lib.licenses.mit;
  };
}
