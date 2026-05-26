{
  config,
  lib,
  pkgs,
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
    home.file = utils.genDirEntries quadletFiles ".config/containers/systemd";

    # FIXME: this whole thing is horribly inefficient...
    home.activation.auto-restart-changed-quadlets =
      let
        stateDir = "${config.home.homeDirectory}/.local/state/home-manager";
        stampFile = "${stateDir}/quadmanix-quadlets.sha256";
        unitNames = map utils.getUnitName quadletFiles;
      in
      lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
        unit_names=( ${lib.concatStringsSep " " (map (p: "\"${p}\"") unitNames)} )
        files=( ${lib.concatStringsSep " " (map (p: "\"${p}\"") quadletFiles)} )

        if [ ''${#files[@]} -gt 0 ]; then
          newsum=$(
            printf "%s\n" ''${files[@]} \
              | sort \
              | xargs -r sha256sum 2>/dev/null \
              | sha256sum \
              | cut -d' ' -f1
          )
        else
          newsum=""
        fi

        oldsum=""
        if [ -f "${stampFile}" ]; then
          oldsum=$(cat "${stampFile}")
        fi

        if [ "$newsum" != "$oldsum" ]; then
          ${pkgs.systemd}/bin/systemctl --user try-restart "''${unit_names[@]}" 
          echo "$newsum" > "${stampFile}"
        fi
      '';
  };
}
