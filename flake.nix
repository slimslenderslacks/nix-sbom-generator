{
  description = "nix sbom generator";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      with pkgs; {
          packages = rec {
              default = pkgs.writeShellScriptBin "entrypoint" ''
                    echo $BUILDKIT_SCAN_SOURCE
                    echo $BUILDKIT_SCAN_DESTINATION
                    ${busybox}/bin/ls -l "$BUILDKIT_SCAN_SOURCE/app"
                    ${busybox}/bin/ls $BUILDKIT_SCAN_SOURCE
                    ${busybox}/bin/cat <<EOF > "$BUILDKIT_SCAN_DESTINATION$(${busybox}/bin/basename $BUILDKIT_SCAN_SOURCE).spdx.json"
                    {
                      "_type": "https://in-toto.io/Statement/v0.1",
                      "predicateType": "https://spdx.dev/Document",
                      "subject": [
                        {
                          "name": "pkg:docker/<registry>/<image>@<tag/digest>?platform=<platform>",
                          "digest": {
                            "sha256": "e8275b2b76280af67e26f068e5d585eb905f8dfd2f1918b3229db98133cb4862"
                          }
                        }
                      ],
                      "predicate": $(< $BUILDKIT_SCAN_SOURCE/app/sbom.spdx.json)
                    }
                    EOF
                    ${busybox}/bin/ls -lR $BUILDKIT_SCAN_DESTINATION
                    ${busybox}/bin/head -n 30 "$BUILDKIT_SCAN_DESTINATION$(${busybox}/bin/basename $BUILDKIT_SCAN_SOURCE).spdx.json"
                    ${busybox}/bin/tail -n 10 "$BUILDKIT_SCAN_DESTINATION$(${busybox}/bin/basename $BUILDKIT_SCAN_SOURCE).spdx.json"
                  '';
              # Remember,
              # if you run this on mac/arm, it'll produce a mac/arm docker image, which is really not very useful!!!
              docker = pkgs.dockerTools.buildImage {
                  name = "vonwig/nix-sbom-generator";
                  tag = "latest";
                  config = {
                      Cmd = [ "${default}/bin/entrypoint" ];
                  };
              };
          };
      });
}
