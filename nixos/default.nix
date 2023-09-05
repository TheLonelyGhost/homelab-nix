_:

{
  imports = [
    # All the modules we can pull in that provide options, not the actual configuration
    ./fabio.nix
    ./flood.nix
    ./seedbox/default.nix
  ];
}
