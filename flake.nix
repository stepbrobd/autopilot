{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };

  outputs = { nixpkgs, parts, systems, ... } @ inputs: {
    inherit (parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;

      perSystem = { pkgs, ... }: { formatter = pkgs.nixpkgs-fmt; };

      flake.lib =
        let
          lib = nixpkgs.lib // parts.lib;

          inherit (builtins)
            attrNames
            elem
            filter
            listToAttrs
            map
            readDir
            substring
            ;

          inherit (lib)
            concatMapStrings
            evalFlakeModule
            removeSuffix
            splitString
            toLower
            toUpper
            ;
        in
        rec {
          /**
            Generates a list of files in a directory, excluding the ones specified in `excludes`.

            # Type: filesList :: Path -> [String] -> [String]

            # Example:
              filesList ./. [ "default.nix" ]
              => [ "file1.nix" "file2.nix" ... ]
          */
          filesList = dir: excludes: map (f: dir + "/${f}") (filter
            (f: !(elem f excludes))
            (attrNames (readDir dir)));

          /**
            Converts a kebab-case string to a camelCase string.
            https://discourse.nixos.org/t/implementing-kebab-case-to-camelcase-in-nix/47313/3

            # Type: kebabToCamel :: String -> String

            # Example:
              kebabToCamel "abc-def-g"
              => "abcDefG"
          */
          kebabToCamel = s:
            mutFirstChar toLower (concatMapStrings
              (mutFirstChar toUpper) # eta reduction
              (splitString "-" s)
            );

          /**
            Imports all `.nix` files in a directory with optional arguments.
            This is meant to be used to load functions from a directory, and use the file name as the function name.

            # Type: loadAll :: { dir :: Path; transformer :: (a -> String); excludes :: [String]; args :: AttrSet } -> AttrSet

            # Example:
              loadAll { dir = ./.
              ; transformer = kebabToCamel
              ; excludes = [ "default.nix" ]
              ; args = { lib = final; }
              }
              => { mkModuleArgs = <function>; ... }
          */
          loadAll =
            { dir ? ./.
            , transformer ? _: _
            , excludes ? [ ]
            , args ? { }
            }: listToAttrs (map
              # file name
              (fn: {
                # name transformation (e.g. "mk-module-args" -> "mkModuleArgs")
                name = transformer (removeSuffix ".nix" fn);
                # function import
                value = import (dir + "/${fn}") args;
              })
              (filter (n: !(elem n excludes)) (attrNames (readDir dir))));

          /**
            Eval Autopilot before invoking flake-parts' `evalFlakeModule`.

            # Type: mkFlake :: (args :: AttrSet) -> (module :: AttrSet) -> AttrSet

            # Example:
              mkFlake { inherit inputs; } { system = [ "x86_64-linux" ]; }
              => { ... }
          */
          mkFlake = # TODO
            args:
            modules:
            (evalFlakeModule args modules).config.flake;

          /**
            Mutates the first character of a string using a function, the rest of the string is left untouched.

            # Type: mutFirstChar :: (a -> String) -> String -> String

            # Example:
              mutFirstChar toUpper "abcd"
              => "Abcd"
          */
          mutFirstChar = f: s:
            let
              first = f (substring 0 1 s);
              rest = substring 1 (-1) s;
            in
            first + rest;
        };
    })
      formatter
      lib
      ;
  };
}
