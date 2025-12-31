let
  smartdns-china-list = { stdenv, fetchFromGitHub, ... }: stdenv.mkDerivation {
      name = "smartdns-china-list";
      src = fetchFromGitHub {
          owner = "felixonmars";
          repo = "dnsmasq-china-list";
          rev = "90e77e94e3184645cad516bc528717b624547917";
          sha256 = "sha256-cHd7uoSUILbE61pQh2kAFIBC4zDaOLuM025NJbDu0OY=";
      };
      buildPhase = ''
          mkdir -p $out
          make SERVER=domestic smartdns
          cp *.smartdns.conf $out
      '';
  };
in {
  perSystem = { pkgs, ... }: {
    packages.smartdns-china-list = pkgs.callPackage smartdns-china-list {};
  };
}
