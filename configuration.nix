{ config, pkgs, ... }:

{
  system.stateVersion = "23.05";
  services.windmill.enable = true;
  services.windmill.baseUrl = "https://windmill-507bd7.flakery.xyz/";
}
