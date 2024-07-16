local: # reference things defined locally

{ ... }: # reference the final user flake

{
  _module.args.local = local;

  imports = local.lib.filesList ./. [ "default.nix" ];
}
