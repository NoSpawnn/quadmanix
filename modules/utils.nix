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
      m = builtins.match "^(.*)\\.(${suffixPattern})$" (baseNameOf path);
      suf = lib.lists.last m;
      bn =
        let
          n = builtins.length m;
        in
        lib.concatStrings (lib.take (n - 1) m);

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
      "${res}.service";

  listFiles =
    dir:
    let
      entries = builtins.readDir dir;
      paths = lib.mapAttrsToList (
        name: type:
        let
          full = "${dir}/${name}";
        in
        if type == "directory" then listFiles full else full
      ) entries;
    in
    lib.flatten paths;

  listQuadletFiles = dir: builtins.filter isQuadletFile (listFiles dir);
  listExtraFiles =
    dir: patterns:
    let
      files = listFiles dir;
      filterFunc =
        path:
        let
          fileName = baseNameOf path;
        in
        builtins.any (pattern: (builtins.match pattern fileName) != null) patterns;
    in
    builtins.filter filterFunc files;

  genDirEntries =
    prefix: files:
    builtins.listToAttrs (
      map (
        p:
        let
          relPath = builtins.head (builtins.match "^/nix/store/[^/]+/(.*)$" p);
          destPath = lib.strings.normalizePath (
            # https://discourse.nixos.org/t/not-allowed-to-refer-to-a-store-path-error/5226/4
            builtins.unsafeDiscardStringContext "${prefix}/${relPath}"
          );
        in
        lib.attrsets.nameValuePair destPath { source = p; }
      ) files
    );
in
{
  inherit
    listQuadletFiles
    listExtraFiles
    genDirEntries
    getUnitName
    ;
}
