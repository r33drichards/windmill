{ config, pkgs, ... }:

{
  system.stateVersion = "23.05";
  services.windmill.enable = true;
}
