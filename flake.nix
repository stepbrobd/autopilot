{
  description = "@stepbrobd: flake parts with autoloading";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
    parts.url = "github:hercules-ci/flake-parts";
    parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    systems.url = "github:nix-systems/default";
  };

  outputs = { nixpkgs, parts, systems, ... } @ inputs: {
    inherit (parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;

      perSystem = { pkgs, ... }: { formatter = pkgs.nixpkgs-fmt; };

      flake.lib =
        let
          lib = builtins // nixpkgs.lib // parts.lib;
          inherit (lib)
            assertMsg
            attrByPath
            attrNames
            concatMapStrings
            elem
            evalFlakeModule
            filter
            intersectLists
            listToAttrs
            makeExtensible
            map
            mapAttrsToList
            mergeAttrsList
            mkIf
            optionals
            readDir
            recursiveUpdate
            removeAttrs
            removeSuffix
            splitString
            substring
            toLower
            toUpper
            ;
        in
        makeExtensible (_: rec {
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

            # Type: loadAll :: { dir :: Path; importer :: (Path -> ?); transformer :: (a -> String); excludes :: [String]; args :: AttrSet } -> AttrSet

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
            , importer ? import
            , transformer ? _: _
            , excludes ? [ ]
            , args ? { }
            }: listToAttrs (map
              # file name
              (fn: {
                # name transformation (e.g. "mk-module-args" -> "mkModuleArgs")
                name = transformer (removeSuffix ".nix" fn);
                # function import
                value = importer (dir + "/${fn}") args;
              })
              (filter (n: !(elem n excludes)) (attrNames (readDir dir))));

          /**
            Eval Autopilot before invoking flake-parts' `evalFlakeModule`.

            # Type: mkFlake :: (args :: AttrSet) -> (module :: AttrSet) -> AttrSet

            # Example:
              mkFlake { inherit inputs; } { system = [ "x86_64-linux" ]; }
              => { ... }
          */
          mkFlake = args: module:
            let
              cfg = recursiveUpdate
                # default config
                {
                  lib = {
                    enable = if (attrByPath [ "autopilot" "lib" "path" ] null args) == null then false else true;
                    path = null; # a sensible default without infinite recursion?
                    excludes = [ ];
                    extender = args.inputs.nixpkgs.lib;
                    extensions = [ ];
                  };

                  nixpkgs = {
                    enable = true;
                    config = { };
                    overlays = [ ];
                    instances = { pkgs = args.inputs.nixpkgs; };
                  };

                  parts = {
                    enable = if (attrByPath [ "autopilot" "parts" "path" ] null args) == null then false else true;
                    path = null; # a sensible default without infinite recursion?
                    excludes = [ ];
                  };
                }
                # user config
                args.autopilot;

              # load `lib` first
              # autopilot.lib = {
              #   path = ./lib;
              #   excludes = [ ... ];
              #   extender = args.inputs.nixpkgs.lib;
              #   extensions = [ ... ];
              # };
              finalLib =
                if cfg.lib.enable && (assertMsg (cfg.lib.extender ? extend) "the extender provide does not have a `extend` function") then
                  cfg.lib.extender.extend
                    (final: prev: mergeAttrsList (
                      # builtins
                      [
                        (removeAttrs builtins (
                          intersectLists (attrNames cfg.lib.extender) (attrNames builtins)
                        ))
                      ]
                      ++
                      # user defined extension list
                      cfg.lib.extensions
                      ++
                      # user provide functions in their project directory
                      [
                        (loadAll {
                          dir = cfg.lib.path;
                          transformer = kebabToCamel;
                          excludes = cfg.lib.excludes;
                          args = { lib = final; };
                        })
                      ]
                    ))
                else { };

              userLib =
                if cfg.lib.enable then
                  removeAttrs
                    finalLib
                    ((attrNames (mergeAttrsList cfg.lib.extensions))
                      ++
                      (attrNames cfg.lib.extender
                        ++
                        attrNames builtins))
                else { };

              # inject `lib` to flake-parts `evalModules`'s `specialArgs`
              finalArgs = removeAttrs (recursiveUpdate args (if cfg.lib.enable then { specialArgs.lib = finalLib; } else { })) [ "autopilot" ];

              finalModule = {
                flake.lib = makeExtensible (_: userLib);

                # customize flake-parts per-system nixpkgs instances
                # autopilot.nixpkgs = {
                #   config = { ... }; # nixpkgs config
                #   overlays = [ ... ]; # nixpkgs overlays
                #   instances = {
                #     pkgs = args.inputs.nixpkgs;
                #     unstable = args.inputs.unstable;
                #   };
                # };
                perSystem = { system, ... }: mkIf cfg.nixpkgs.enable {
                  _module.args = listToAttrs (
                    mapAttrsToList
                      (pkgsName: pkgsInstance: {
                        name = pkgsName;
                        value = import pkgsInstance { inherit system; inherit (cfg.nixpkgs) config overlays; };
                      })
                      cfg.nixpkgs.instances
                  );
                };

                # user defined flake-part module
                imports = [ module ]
                  # load user flake-parts
                  # autopilot.parts = {
                  #   path = ./parts;
                  #   excludes = [ ... ];
                  # };
                  ++ optionals cfg.parts.enable (filesList cfg.parts.path cfg.parts.excludes);
              };

              # eval result
              inherit ((evalFlakeModule finalArgs finalModule).config) flake;
            in
            if flake.debug.debug or false
            then { inherit (args) autopilot; } // flake
            else flake;

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
        });
    })
      formatter
      lib
      ;
  };
}
