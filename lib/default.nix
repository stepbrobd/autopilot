{ lib }:

let
  inherit (builtins) readDir;
  inherit (lib)
    attrNames
    concatMapStrings
    elem
    filter
    listToAttrs
    map
    removeSuffix
    splitString
    substring
    toLower
    toUpper
    ;
in
rec {
  /**
    Converts a kebab-case string to a camelCase string.
    https://discourse.nixos.org/t/implementing-kebab-case-to-camelcase-in-nix/47313/3

    Type: kebabToCamel :: string -> string

    Example:
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

    # Type: loadAll :: { dir :: path; transformer :: (a -> string); excludes :: [string]; args :: attrset } -> attrset

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
    Mutates the first character of a string using a function, the rest of the string is left untouched.

    Type: mutFirstChar :: (a -> string) -> string -> string

    Example:
      mutFirstChar toUpper "abcd"
      => "Abcd"
  */
  mutFirstChar = f: s:
    let
      first = f (substring 0 1 s);
      rest = substring 1 (-1) s;
    in
    first + rest;
}
