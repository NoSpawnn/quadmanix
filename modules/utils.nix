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
  isQuadletFile = path: builtins.any (suf: lib.strings.hasSuffix suf path) quadletSuffixes;

  suffixPattern = lib.concatStringsSep "|" (map (s: lib.removePrefix "." s) quadletSuffixes);
  getUnitName =
    path:
    let
      # FIXME: this doesnt correctly handle networks or pods
      bn = baseNameOf path;
      m = builtins.match "^(.*)\\.(${suffixPattern})$" bn;
    in
    assert m != null;
    builtins.head m;

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
    prefix: quadletFiles: 
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
  inherit listQuadletFiles genDirEntries getUnitName;
}
