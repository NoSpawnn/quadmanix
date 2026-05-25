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

  listHosts =
    dir:
    let
      entries = builtins.readDir dir;
      hosts = builtins.filter ({ type, ... }: type == "directory") entries;
    in
    hosts;
in
{
  inherit listQuadletFiles;
}
