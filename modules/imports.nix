{ self  # reference the final user flake
, lib
, config
, ...
}:

let
  inherit (builtins) attrNames elem filter map readDir toPath;
  inherit (lib) mkOption types;

  cfg = config.autopilot.imports;
in
{
  options.autopilot.imports = {
    path = mkOption {
      type = types.path;
      default = toPath "${self}/parts/.";
      example = ../parts;
      description = ''
        The path to all flake-parts modules that you want to import.
      '';
    };

    excludes = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [ "default.nix" ];
      description = ''
        A list of files inside the flake-parts directory that you want to exclude.
      '';
    };
  };

  # broken
  # config = { };
}
