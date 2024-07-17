{ config, pkgs, ... }:

{
  system.stateVersion = "23.05";
  services.windmill.enable = true;
  services.windmill.baseUrl = "https://windmill-507bd7.flakery.xyz/";
  services.windmill.database.urlPath = "/dburl";
  services.postgresql = {
    authentication = pkgs.lib.mkBefore ''
      host    windmill        windmill        127.0.0.1/32            trust
    '';
  };
}
