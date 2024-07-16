args:

let
  inherit (args.inputs) self;
  inherit (args.inputs.parts.lib) importApply;

  flakeModules = rec {
    autopilot = importApply ../modules self;
    default = autopilot;
  };
in
{ flake = { inherit flakeModules; }; }
