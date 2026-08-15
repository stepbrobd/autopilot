{
  description = "@stepbrobd: flake parts with autoloading";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
    parts.url = "github:hercules-ci/flake-parts";
    parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    systems.url = "github:nix-systems/triplet";
  };

  outputs = { self, nixpkgs, parts, systems } @ inputs: {
    inherit (parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;

      perSystem = { pkgs, ... }: { formatter = pkgs.nixpkgs-fmt; };

      flake.lib =
        let
          lib = builtins // nixpkgs.lib // parts.lib;
          inherit (lib)
            assertMsg
            attrNames
            concatMapStrings
            elem
            evalFlakeModule
            evalModules
            filter
            intersectLists
            listToAttrs
            makeExtensible
            map
            mapAttrs
            mergeAttrsList
            mkDefault
            mkIf
            mkOption
            optionals
            readDir
            recursiveUpdate
            removeAttrs
            removeSuffix
            splitString
            substring
            toLower
            toUpper
            types
            ;
        in
        makeExtensible (_: rec {
          /**
            Generates a list of paths in a directory, excluding the names specified in `excludes`.
            Directory entries are included, importing such a path loads its `default.nix`.

            # Type: filesList :: Path -> [String] -> [Path]

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
            The default importer is `import`, so every loaded file must be a function that accepts `args`.

            # Type: loadAll :: { dir :: Path; importer :: (Path -> AttrSet -> a); transformer :: (String -> String); excludes :: [String]; args :: AttrSet } -> AttrSet

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
              # user config is checked against declared options
              # an unknown option name or a wrong type fails eval instead of being silently carried
              cfg = (evalModules {
                prefix = [ "autopilot" ];
                modules = [
                  ({ config, ... }: {
                    options = {
                      lib = {
                        enable = mkOption { type = types.bool; };
                        path = mkOption { type = types.nullOr types.path; default = null; };
                        excludes = mkOption { type = types.listOf types.str; default = [ ]; };
                        # falls back to autopilot's own nixpkgs when the caller has no `nixpkgs` input
                        extender = mkOption { type = types.raw; default = args.inputs.nixpkgs.lib or self.inputs.nixpkgs.lib; };
                        extensions = mkOption { type = types.listOf types.raw; default = [ ]; };
                      };

                      nixpkgs = {
                        enable = mkOption { type = types.bool; default = true; };
                        config = mkOption { type = types.raw; default = { }; };
                        overlays = mkOption { type = types.listOf types.raw; default = [ ]; };
                        instances = mkOption { type = types.attrsOf types.raw; default = { }; };
                      };

                      parts = {
                        enable = mkOption { type = types.bool; };
                        path = mkOption { type = types.nullOr types.path; default = null; };
                        excludes = mkOption { type = types.listOf types.str; default = [ ]; };
                      };
                    };

                    config = {
                      lib.enable = mkDefault (config.lib.path != null);
                      parts.enable = mkDefault (config.parts.path != null);
                      # a definition instead of an option default so user provided instances merge with it
                      # falls back to autopilot's own nixpkgs when the caller has no `nixpkgs` input
                      nixpkgs.instances.pkgs = mkDefault (args.inputs.nixpkgs or self.inputs.nixpkgs);
                    };
                  })
                  # user config
                  (args.autopilot or { })
                ];
              }).config;

              # load `lib` first
              # autopilot.lib = {
              #   path = ./lib;
              #   excludes = [ ... ];
              #   extender = args.inputs.nixpkgs.lib;
              #   extensions = [ ... ];
              # };
              mergedExtensions = mergeAttrsList cfg.lib.extensions;

              finalLib =
                if cfg.lib.enable && (assertMsg (cfg.lib.extender ? extend) "the extender does not provide an `extend` function") then
                  cfg.lib.extender.extend
                    (final: prev: mergeAttrsList [
                      # builtins
                      (removeAttrs builtins (
                        intersectLists (attrNames cfg.lib.extender) (attrNames builtins)
                      ))
                      # user defined extension list
                      mergedExtensions
                      # user provided functions in their project directory
                      (loadAll {
                        dir = cfg.lib.path;
                        transformer = kebabToCamel;
                        excludes = cfg.lib.excludes;
                        args = { lib = final; };
                      })
                    ])
                else { };

              userLib =
                if cfg.lib.enable then
                  removeAttrs finalLib (attrNames mergedExtensions ++ attrNames cfg.lib.extender ++ attrNames builtins)
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
                  _module.args = mapAttrs
                    (_: pkgsInstance: import pkgsInstance { inherit system; inherit (cfg.nixpkgs) config overlays; })
                    cfg.nixpkgs.instances;
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
            then { autopilot = args.autopilot or { }; } // flake
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
