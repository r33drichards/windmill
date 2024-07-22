{ config, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 8001 ];
  services.envfs.enable = true; # for /bin/bash
  services.envfs.extraFallbackPathCommands = "ln -s $''{pkgs.bash}/bin/bash $out/bash";

  # Here we setup podman and enable dns
  virtualisation.podman = {
    enable = true;
    defaultNetwork.settings = {
      dns_enabled = true;
    };
    dockerSocket.enable = true;
    dockerCompat = true;
  };
  # This is needed for podman to be able to talk over dns
  networking.firewall.interfaces."podman0" = {
    allowedUDPPorts = [ 53 ];
    allowedTCPPorts = [ 53 ];
  };
  

  systemd.services.windmill-worker = {
    path = [ pkgs.nix pkgs.curl pkgs.jq ];
  }

  system.stateVersion = "23.05";
  services.windmill.enable = true;
  services.windmill.baseUrl = "https://windmill-507bd7.flakery.xyz/";
  services.windmill.database.urlPath = "/dburl";
  services.postgresql = {
    authentication = pkgs.lib.mkForce ''
      host    windmill        windmill        127.0.0.1/32            trust
      local   all             all                                     trust
      # IPv4 local connections:
      host    all             all             127.0.0.1/32            trust
      # IPv6 local connections:
      host    all             all             ::1/128                 trust
      # Allow replication connections from localhost, by a user with the
      # replication privilege.
      local   replication     all                                     trust
      host    replication     all             127.0.0.1/32            trust
      host    replication     all             ::1/128                 trust
    '';
  };
}
