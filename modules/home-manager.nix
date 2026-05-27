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

    # FIXME: this whole thing is horribly inefficient...
    home.activation.auto-restart-changed-quadlets =
      let
        unitNames = map utils.getUnitName quadletFiles;

        stateDir = "\${XDG_STATE_HOME:-$HOME/.local/state}/home-manager/gcroots";
        newStateFile = pkgs.writeText "quadmanix-quadlets.json" (
          builtins.toJSON {
            quadlets = map (q: {
              name = baseNameOf q;
              hash = builtins.hashString "sha256" (builtins.readFile q);
            }) quadletFiles;
          }
        );
        statePath = "${stateDir}/${newStateFile.name}";
        oldStateFile = statePath;

        dictEntries = map (p: "quadmanix_files[${p.name}]=${p.value}") (
          lib.zipListsWith (k: v: {
            name = builtins.unsafeDiscardStringContext (baseNameOf k);
            value = builtins.unsafeDiscardStringContext v;
          }) quadletFiles unitNames
        );
      in
      lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
        newstate="''$(${pkgs.coreutils}/bin/cat ${newStateFile})"
        jq="${pkgs.jq}/bin/jq"
        declare -A quadmanix_files
        ${lib.concatStringsSep "\n" dictEntries}

        to_start=()
        to_stop=()
        to_restart=()
        for name in ''${!quadmanix_files[@]}; do
          if [[ $($jq -e --arg name "$name" 'any(.quadlets[]; .name == $name)' "${oldStateFile}" >/dev/null 2>&1) && ! $($jq -e --arg name "$name" 'any(.quadlets[]; .name == $name)' "${newStateFile}" >/dev/null 2>&1) ]]; then
            # FIXME: this doesnt work since this file doesnt exist in the dict
            to_stop+=("''${quadmanix_files[''$name]}")
            continue
          fi

          if $jq -e --arg name "$name" 'any(.quadlets[]; .name == $name)' "${oldStateFile}" >/dev/null 2>&1; then
            to_start+=("''${quadmanix_files[''$name]}")
          fi

          old_hash=$($jq -r --arg name "$name" '(.quadlets[] | select(.name == $name) | .hash) // ""' "${oldStateFile}")
          new_hash=$($jq -r --arg name "$name" '(.quadlets[] | select(.name == $name) | .hash) // ""' "${newStateFile}")
          if [ "$old_hash" != "$new_hash" ]; then
            to_restart+=("''${quadmanix_files[''$name]}")
          fi
        done

        if [ ''${#to_start[@]} -gt 0 ]; then
          ${pkgs.systemd}/bin/systemctl --user start ''${to_start[@]}
        fi

        if [ ''${#to_stop[@]} -gt 0 ]; then
          ${pkgs.systemd}/bin/systemctl --user stop ''${to_stop[@]}
        fi

        if [ ''${#to_restart[@]} -gt 0 ]; then
          ${pkgs.systemd}/bin/systemctl --user restart ''${to_restart[@]} 
        fi

        echo "$newstate" > "${statePath}"
      '';
  };
}
