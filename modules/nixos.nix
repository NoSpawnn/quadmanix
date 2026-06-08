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

  quadletUsers = builtins.filter ({ value, ... }: value.services.quadmanix.enable or false) (
    lib.attrsets.attrsToList config.home-manager.users
  );
  autoCreatedUsers = lib.genAttrs (map (u: u.name) quadletUsers) (_: {
    isNormalUser = true;
    linger = true;
    extraGroups = [ "podman" ];
  });

  quadletFiles = utils.listQuadletFiles cfg.quadlets.source;
in
{
  options.services.quadmanix = {
    enable = mkEnableOption "quadmanix";

    autoCreateUsers = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically create users defined in the HomeManager module of Quadmanix. Can be set independantly of enable.";
    };

    quadlets = {
      source = mkOption {
        type = types.nullOr types.path;
        description = "Directory from which to source this machine's system Quadlets.";
      };
    };
  };

  config = lib.mkMerge [
    # podman needs to be enabled for any of this to work, system or not, but there is maybe a nicer way to do this, or just trust the end user to enable it if the system module isn't enabled? same with the auto user creation. much to think about.
    (mkIf (cfg.enable || quadletUsers != [ ]) {
      virtualisation.containers.enable = true;
      virtualisation.podman.enable = true;
    })

    (mkIf (cfg.quadlets.source != null) {
      environment.etc = utils.genDirEntries "containers/systemd" quadletFiles;
    })

    (mkIf cfg.autoCreateUsers {
      users.users = autoCreatedUsers;
    })
  ];
}
