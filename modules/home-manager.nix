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
  homeFileEntries = utils.genDirEntries {
    inherit quadletFiles;
    prefix = ".config/containers/systemd";
  };
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
