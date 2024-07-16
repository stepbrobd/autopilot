{ local # reference things defined locally
, self  # reference the final user flake
, lib
, config
, ...
}:

let
  inherit (builtins) toPath;
  inherit (lib) mergeAttrsList mkOption types;
  inherit (local.lib) kebabToCamel loadAll;

  cfg = config.autopilot;
in
{
  options.autopilot.lib = {
    name = mkOption {
      type = types.str;
      default = "lib";
      example = "lib";
      description = ''
        The name of the flake attribute.
      '';
    };

    path = mkOption {
      type = types.path;
      default = toPath "${self}/lib/.";
      example = ../lib;
      description = ''
        The path to all library functions to be auto-loaded.
      '';
    };

    excludes = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [ "private.nix" ];
      description = ''
        A list of functions to exclude from the auto-loading.
        You should put the file names here.
      '';
    };

    base = mkOption {
      type = with types; attrsOf unspecified;
      default = local.inputs.nixpkgs.lib;
      example = lib;
      description = ''
        Any attrset that has the function `extend` defined.
        Usually, the `nixpkgs.lib` should be passed here.
      '';
    };

    extensions = mkOption {
      type = with types; listOf (attrsOf unspecified);
      default = [ ];
      example = [{ addOne = x: x + 1; }];
      description = ''
        A list of library functions that you want to extend the base with.
      '';
    };
  };

  config.flake.lib = cfg.lib.base.extend (final: prev: mergeAttrsList (
    cfg.lib.extensions ++ [
      (loadAll {
        dir = cfg.lib.path;
        transformer = kebabToCamel;
        excludes = cfg.lib.excludes;
        args = { lib = final; };
      })
    ]
  ));
}