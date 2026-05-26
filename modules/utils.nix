{ lib, ... }:

let
  quadletSuffixes = [
    ".container"
    ".network"
    ".volume"
    ".pod"
    ".image"
    ".kube"
  ];
  isQuadletFile = s: builtins.any (suf: lib.strings.hasSuffix suf s) quadletSuffixes;

  listQuadletFiles =
    dir:
    let
      entries = builtins.readDir dir;
      paths = lib.mapAttrsToList (
        name: type:
        let
          full = "${dir}/${name}";
        in
        if type == "directory" then listQuadletFiles full else full
      ) entries;
    in
    builtins.filter isQuadletFile (lib.flatten paths);

  genDirEntries =
    { quadletFiles, prefix }:
    builtins.listToAttrs (
      map (
        p:
        let
          fileName = baseNameOf p;
          # https://discourse.nixos.org/t/not-allowed-to-refer-to-a-store-path-error/5226/4
          destPath = builtins.unsafeDiscardStringContext "${prefix}/${fileName}";
        in
        lib.attrsets.nameValuePair destPath { source = p; }
      ) quadletFiles
    );
in
{
  inherit listQuadletFiles genDirEntries;
}
