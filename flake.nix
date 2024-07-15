{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
