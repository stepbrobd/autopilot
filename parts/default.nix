args:

{
  # automatic import, but must exclude `default.nix` and `lib.nix` to prevent infinite recursion
  imports = [ ./lib.nix ] ++ (
    let
      inherit (builtins) attrNames filter map readDir;
    in
    map (f: ./. + "/${f}") (filter
      (f: !(f == "default.nix" || f == "lib.nix"))
      (attrNames (readDir ./.)))
  );
}
