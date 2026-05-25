{ lib, ... }:

let
  inherit (lib) types mkEnableOption mkOption;
in
{
  options.services.quadmanix = {
    enable = mkEnableOption {
      name = "quadmanix";
    };

    quadletsRootDir = mkOption {
      type = types.path;
      description = ''
        The root directory from which to source Quadlets .
      '';
    };

    # TODO
    # userOverrides = mkOption {
    #     type = types.attrsOf;
    #     description = ''
    #
    #     '';
    # };
  };
}
