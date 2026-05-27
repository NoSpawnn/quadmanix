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
      bn = baseNameOf path;
      m = builtins.match "^(.*)\\.(${suffixPattern})$" bn;
      suf = lib.lists.last m;

      # TODO: handle .image and .build
      res =
        if suf == "pod" then
          "${bn}-pod"
        else if suf == "network" then
          "${bn}-network"
        else if suf == "volume" then
          "${bn}-volume"
        else if suf == "container" || suf == "kube" then
          "${bn}"
        else
          null;
    in
    if res == null then
      # this should never happen due to the list of files always being acquired through `listQuadletFiles`
      throw "file '${bn}' does not have a valid quadlet extension ('${suf}')"
    else
      res;

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
