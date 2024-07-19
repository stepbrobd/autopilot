# Autopilot

[![Built with Nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)

Automatically loads and extends your configurations, libraries, packages, and
more with [flake-parts](https://flake.parts).

## Library Auto-loading

Autopilot evaluates user defined library before letting flake-parts takeover.
User defined library (including extensions) will be passed as `specialArgs` to
flake-parts, i.e. `lib` will be made available to flake-parts modules and
`perSystem` configurations.

### Options

#### `autopilot.lib.path`

The directory Autopilot will load `.nix` files from. File names will be used to
generate function names. All files in this directory should be in `kebab-case`.
Function names will be in `camelCase`. For instance, `add-one.nix` will be
transformed to `addOne`.

Type: Path

Example: `autopilot.lib.path = ./lib;`

#### `autopilot.lib.excludes`

Files in `autopilot.lib.path` that should be ignored.

Type: [String]

Example:
`autopilot.lib.excludes = [ "do-not-use-me-or-you-will-be-fired.nix" ];`

#### `autopilot.lib.extender`

An attrset contains the function `extend`. Usually `nixpkgs.lib`, or any
function set called with `nixpkgs.lib.makeExtensible`.

Type: AttrSet

Example: `autopilot.lib.extender = inputs.nixpkgs.lib;`

#### `autopilot.lib.extensions`

Any library(ies) that you want to use in your flake-parts config. They will be
made available in your flake-parts modules but will not be exported to
`flake.lib`.

Type: [AttrSet]

Example:
`autopilot.lib.extensions = with inputs; [ autopilot.lib flake-parts.lib flake-utils.lib ];`

## Setting Multiple `nixpkgs` Instances

This option enables users to set one or more `nixpkgs` instances with config and
overlays. Instances provided in `autopilot.nixpkgs.instances` will inherit
`config` and `overlays`.

### Options

#### `autopilot.nixpkgs.config`

Must be a valid `nixpkgs` config.

Type: AttrSet

Example: `autopilot.nixpkgs.config = { allowUnfree = true; };`

#### `autopilot.nixpkgs.overlays`

Must be a list of valid `nixpkgs` overlays.

Type: [(AttrSet -> AttrSet -> AttrSet)]

Example: `autopilot.nixpkgs.overlays = [ (final: prev: { hi = prev.hello; }) ];`

#### `autopilot.nixpkgs.instances`

Instances of `nixpkgs` that will be made available to `perSystem`
configurations.

Type: [AttrSet]

Example:`autopilot.nixpkgs.instances = [ { name = "pkgs"; value = inputs.nixpkgs; } ];`

## Module Auto-loading

Automatically import all files (flake-part) modules in a directory.

### Options

#### `autopilot.parts.path`

The directory Autopilot will load `.nix` files from.

Type: Path

Example: `autopilot.lib.parts = ./parts;`

#### `autopilot.parts.excludes`

Files in `autopilot.parts.path` that should be ignored.

Type: [String]

Example:
`autopilot.parts.excludes = [ "do-not-use-me-or-you-will-be-fired.nix" ];`

## Example

Multi-directory flake:

```nix
# ./flake.nix

{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/release-24.05";
        unstable.url = "github:nixos/nixpkgs/nixos-unstable";

        parts.url = "github:hercules-ci/flake-parts";
        parts.inputs.nixpkgs-lib.follows = "nixpkgs";

        systems.url = "github:nix-systems/default";

        autopilot.url = "github:stepbrobd/autopilot";
        autopilot.inputs.nixpkgs.follows = "nixpkgs";
        autopilot.inputs.parts.follows = "parts";
        autopilot.inputs.systems.follows = "systems";
    };

    outputs = inputs: inputs.autopilot.lib.mkFlake
    {
        inherit inputs;

        autopilot = {
            lib = {
                path = ./lib;
                excludes = [ ];
                extender = inputs.nixpkgs.lib;
                extensions = with inputs; [ autopilot.lib parts.lib ];
            };

            nixpkgs = {
                config = { allowUnfree = true; };
                overlays = [ ];
                instances = [
                    { name = "pkgs"; value = inputs.nixpkgs; }
                    { name = "unstable"; value = inputs.unstable; }
                ];
            };

            parts = { path = ./parts; excludes = [ ]; };
        };
    }
    { systems = import inputs.systems; };
}
```

```nix
# ./lib/add-one.nix # will be made available as `lib.addOne`

{ lib }:

x: x + 1
```

```nix
# ./parts/formatter.nix

{
    perSystem = { unstable, ... }: {
        formatter = unstable.nixpkgs-fmt;
    };
}
```

## License

All contents inside this repository, excluding submodules, are licensed under
the [MIT License](license.txt). Third-party file(s) and/or code(s) are subject
to their original term(s) and/or license(s).
