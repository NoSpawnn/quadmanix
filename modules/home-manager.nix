{
  config,
  lib,
  ...
}:

let
  inherit (lib)
    types
    mkOption
    mkEnableOption
    mkIf
    ;
  utils = import ./utils.nix { inherit lib; };

  cfg = config.services.quadmanix;

  quadletFiles = utils.listQuadletFiles cfg.quadlets.source;
  homeFileEntries = builtins.listToAttrs (
    map (
      p:
      let
        fileName = builtins.baseNameOf p;
        # https://discourse.nixos.org/t/not-allowed-to-refer-to-a-store-path-error/5226/4
        destPath = builtins.unsafeDiscardStringContext ".config/containers/systemd/${fileName}";
      in
      lib.attrsets.nameValuePair destPath { source = p; }
    ) quadletFiles
  );
in
{
  options.services.quadmanix = {
    enable = mkEnableOption "quadmanix";
    quadlets = {
      source = mkOption {
        type = types.path;
        description = "Directory from which to source this user's Quadlets.";
      };
    };
  };

  config = mkIf cfg.enable {
    home.file = homeFileEntries;
  };
}
