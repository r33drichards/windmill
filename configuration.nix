{ config, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 3007 5000 9002 8001 ];

  services.envfs.enable = true; # for /bin/bash
  services.envfs.extraFallbackPathCommands = "ln -s $''{pkgs.bash}/bin/bash $out/bash";

  systemd.services.windmill-worker = {
    path = [
      pkgs.nix
      pkgs.curl
      pkgs.jq
      pkgs.git
      pkgs.ripgrep
    ];
  };

  system.stateVersion = "23.05";
  services.windmill.enable = true;
  services.windmill.baseUrl = "https://windmill-ng-6db26f.flakery.xyz/";
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


  systemd.services.comin = {
    environment = {
      "TEMPLATE_ID" = (pkgs.lib.removeSuffix "\n" (builtins.readFile /metadata/template-id));
      "USER_TOKEN" = (pkgs.lib.removeSuffix "\n" (builtins.readFile /metadata/user-token));
    };
  };
  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 9080;
        grpc_listen_port = 0;
      };
      clients = [{ url = "http://grafana:3100/loki/api/v1/push"; }];
      scrape_configs = [
        {
          job_name = "system";
          static_configs = [
            {
              targets = [ "localhost" ];
              labels = {
                job = "varlogs";
                __path__ = "/var/log/*log";
              };
            }

          ];
        }
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = "windmill";
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }

      ];
    };
  };

  services.prometheus = {
    enable = true;
    port = 9090;
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = 9002;
      };

    };
  };
  services.comin = {
    enable = true;
    hostname = "flakery";
    remotes = [
      {
        name = "origin";
        url = "https://github.com/r33drichards/windmill";
        poller.period = 2;
      }
    ];
  };
}
