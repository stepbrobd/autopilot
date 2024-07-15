{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    compat.url = "github:edolstra/flake-compat";
    compat.flake = false;
    parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };

  outputs = { parts, systems, ... } @ inputs: parts.lib.mkFlake
    { inherit inputs; }
    {
      systems = import systems;
      imports = [ ./parts ];
    };
}
