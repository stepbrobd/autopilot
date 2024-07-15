args:

let
  # base
  inherit (args.inputs.nixpkgs) lib;

  # extensions
  inherit (args.inputs) parts;
in
# understanding of fixpoint is needed here
  # https://github.com/nixos/nixpkgs/blob/master/lib/fixed-points.nix
  # `final` needs to be passed to all imported files inside this folder
lib.extend (final: prev: lib.mergeAttrsList [
  # extensions
  parts.lib

  # automatic import with name transformation
  # implement in a cleaner way?
  (
    let
      # kebabToCamel "abc-def-g" -> "abcDefG"
      # https://discourse.nixos.org/t/implementing-kebab-case-to-camelcase-in-nix/47313/3
      kebabToCamel = s:
        mutFirstChar lib.toLower (lib.concatMapStrings
          (mutFirstChar lib.toUpper) # eta reduction
          (lib.splitString "-" s)
        );

      # imports all nix files in `dir` with `args`
      # excluding files specified in `exclude`
      # and change the original file names with `transformer`
      loadAll =
        { dir ? ./.
        , transformer ? _: _
        , exclude ? [ ]
        , args ? { }
        }: lib.listToAttrs (builtins.map
          # file name
          (fn: {
            # name transformation (e.g. "mk-module-args" -> "mkModuleArgs")
            name = transformer (lib.removeSuffix ".nix" fn);
            # function import
            value = import (dir + "/${fn}") args;
          })
          (lib.filter (n: !(lib.elem n exclude)) (lib.attrNames (builtins.readDir dir))));

      # mutFirstChar toUpper "abcd" -> "Abcd"
      mutFirstChar = f: s:
        let
          first = f (lib.substring 0 1 s);
          rest = lib.substring 1 (-1) s;
        in
        first + rest;
    in
    { inherit kebabToCamel loadAll mutFirstChar; } // loadAll {
      dir = ./.;
      transformer = kebabToCamel;
      exclude = [ "default.nix" ];
      args = { lib = final; };
    }
  )
])
