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
    home.file = utils.genDirEntries ".config/containers/systemd" quadletFiles;

    # TODO: implemen a restart strategy option? to control the exact systemctl command that is used for that
    home.activation.auto-restart-changed-quadlets =
      let
        stateFileVersion = 1;

        unitNames = map utils.getUnitName quadletFiles;

        stateDir = "\${XDG_STATE_HOME:-$HOME/.local/state}/home-manager/gcroots";
        newStateFile = pkgs.writeText "quadmanix-quadlets.json" (
          builtins.toJSON {
            version = stateFileVersion;
            quadlets = map (q: {
              name = baseNameOf q;
              hash = builtins.hashString "sha256" (builtins.readFile q);
              unitName = utils.getUnitName q;
            }) quadletFiles;
          }
        );
        statePath = "${stateDir}/${newStateFile.name}";
        oldStateFile = statePath;
      in
      lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
        jq="${pkgs.jq}/bin/jq"

        if [ ! -f ${oldStateFile} ]; then
          to_start=( ${lib.concatStringsSep " " (map (p: "\"${p}\"") unitNames)} )
          to_stop=()
          to_restart=()
        else
          old_state_version=$($jq -r '.version' "${oldStateFile}")

          if [ $old_state_version -eq 1 ]; then
            to_start=()
            to_stop=()
            to_restart=()

            while IFS=$'\t' read -r name unitName; do
              in_new_statefile=$($jq -e --arg name "$name" 'any(.quadlets[]; .name == $name)' "${newStateFile}" >/dev/null 2>&1 && echo "true" || echo "false")
              if [ $in_new_statefile == "false" ]; then
                to_stop+=("$unitName")
              fi
            done < <($jq -r '.quadlets[] | [.name, .unitName] | @tsv' "${oldStateFile}")

            while IFS=$'\t' read -r name unit_name new_hash; do
              in_old_statefile=$($jq -e --arg name "$name" 'any(.quadlets[]; .name == $name)' "${oldStateFile}" >/dev/null 2>&1 && echo "true" || echo "false")

              if [ "$in_old_statefile" == "false" ]; then
                to_start+=("$unit_name")
              else
                old_hash=$($jq -r --arg name "$name" '(.quadlets[] | select(.name == $name) | .hash) // ""' "${oldStateFile}")
                if [ "$old_hash" != "$new_hash" ]; then
                  to_restart+=("$unit_name")
                fi
              fi
            done < <($jq -r '.quadlets[] | [.name, .unitName, .hash] | @tsv' "${newStateFile}")
          else
            ${pkgs.coreutils}/bin/echo "Quadmanix: unknown statefile version \"$old_state_version\""
            exit 1
          fi
        fi

        if [ ''${#to_start[@]} -gt 0 ]; then
          ${pkgs.systemd}/bin/systemctl --user start ''${to_start[@]}
        fi

        if [ ''${#to_stop[@]} -gt 0 ]; then
          ${pkgs.systemd}/bin/systemctl --user stop ''${to_stop[@]}
        fi

        if [ ''${#to_restart[@]} -gt 0 ]; then
          ${pkgs.systemd}/bin/systemctl --user restart ''${to_restart[@]} 
        fi

        ${pkgs.coreutils}/bin/cat ${newStateFile} > ${oldStateFile}
      '';
  };
}
