args:

{
  flake.lib = import ../lib { inherit (args.inputs.nixpkgs) lib; };
}
