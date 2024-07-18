{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };

  outputs = { nixpkgs, parts, systems, ... } @ inputs: parts.lib.mkFlake
    { inherit inputs; }
    {
      systems = import systems;
      imports = (import ./lib { inherit (nixpkgs) lib; }).filesList ./parts [ ];
    };
}
