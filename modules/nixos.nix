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

  quadletUsers = lib.filterAttrs (
    _: u:
    lib.attrByPath [
      "services"
      "quadmanix"
      "enable"
    ] false u
  ) config.home-manager.users;
  autoCreatedUsers = lib.genAttrs (builtins.attrNames quadletUsers) (_: {
    isNormalUser = true;
    linger = true;
    extraGroups = [ "podman" ];
  });
in
{
  options.services.quadmanix = {
    enable = mkEnableOption "quadmanix";
    autoCreateUsers = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically create users defined in the HomeManager module of Quadmanix. Can be set independantly of enable.";
    };
  };

  config = lib.mkMerge [
    (mkIf cfg.enable {
      virtualisation.podman.enable = true;
    })

    {
      users.users = mkIf cfg.autoCreateUsers autoCreatedUsers;
    }
  ];
}
