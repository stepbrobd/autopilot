{ local # reference things defined locally
, self  # reference the final user flake
, lib
, config
, ...
}:

let
  inherit (builtins) toPath;
  inherit (lib) literalExpression mergeAttrsList mkOption types;
  inherit (local.lib) kebabToCamel loadAll;

  cfg = config.autopilot.lib;
in
{
  options.autopilot.lib = {
    name = mkOption {
      type = types.str;
      default = "lib";
      example = literalExpression ''"lib"'';
      description = ''
        The name of the flake attribute.
      '';
    };

    path = mkOption {
      type = types.path;
      default = toPath "${self.outPath}/lib/."; # user flake's outPath + "./lib"
      example = literalExpression ''./lib'';
      description = ''
        The path to all library functions to be auto-loaded.
      '';
    };

    excludes = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = literalExpression ''[ "default.nix" ]'';
      description = ''
        A list of files to exclude from the auto-loading.
        You should put filename with extension **inside** the `path` directory if you want to exclude them.
      '';
    };

    extender = mkOption {
      type = types.raw;
      default = local.inputs.nixpkgs.lib.extend;
      example = literalExpression ''nixpkgs.lib.extend'';
      description = ''
        A function that extends the base library.
        Usually, the `nixpkgs.lib.extend` function is used.
      '';
    };

    extensions = mkOption {
      type = with types; listOf (lazyAttrsOf raw);
      default = [ ];
      example = literalExpression ''[ { addOne = x: x + 1; } { addTwo = x: x + 2; } ]'';
      description = ''
        A list of library functions that you want to extend the base with.
        In case of name collisions, the ones defined later will override the previous ones.
      '';
    };
  };

  config.flake.lib = cfg.extender (final: prev: mergeAttrsList (
    cfg.extensions ++ [
      (loadAll {
        dir = cfg.path;
        transformer = kebabToCamel;
        excludes = cfg.excludes;
        args = { lib = final; };
      })
    ]
  ));
}
