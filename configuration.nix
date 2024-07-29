{ config, pkgs, ... }:

{

  environment.systemPackages = with pkgs; [
    awscli2
    curl
    git
    jq
    ripgrep
    openssh
    gawk
    nix
    bash
  ];
  networking.firewall.allowedTCPPorts = [ 3007 5000 9002 8001 ];

  services.envfs.enable = true; # for /bin/bash
  services.envfs.extraFallbackPathCommands = "ln -s $''{pkgs.bash}/bin/bash $out/bash";

  systemd.services.windmill-worker = {
    # wait for restore db to complete
    after = [ "restore.service" ];
    path = [
      pkgs.nix
      pkgs.curl
      pkgs.jq
      pkgs.git
      pkgs.ripgrep
      pkgs.openssh
      pkgs.gawk
      pkgs.awscli2
    ];
  };

  systemd.services.windmill-worker-native = {
    # wait for restore db to complete
    after = [ "restore.service" ];
  };

  # windmill-worker.service   
  systemd.services.windmill-native = {
    after = [ "restore.service" ];
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

  # add postgres backup
    # Define the sync service
  systemd.services.sync-postgresql-backup = {
    description = "Sync PostgreSQL backup to S3";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.awscli2 pkgs.jq];
    environment = {
      AWS_ACCESS_KEY_ID = (pkgs.lib.removeSuffix "\n" (builtins.readFile /aws-access-key-id));
      AWS_SECRET_ACCESS_KEY = (pkgs.lib.removeSuffix "\n" (builtins.readFile /aws-secret-access-key));
      AWS_REGION = "us-west-2";
    };
    script = ''
      # assume role arn:aws:iam::150301572911:role/windmill 
      # Assume the role and capture the output in a variable
      output=$(aws sts assume-role \
          --role-arn arn:aws:iam::150301572911:role/windmill \
          --role-session-name MySession)

      # Extract the temporary credentials from the output
      export AWS_ACCESS_KEY_ID=$(echo $output | jq -r '.Credentials.AccessKeyId')
      export AWS_SECRET_ACCESS_KEY=$(echo $output | jq -r '.Credentials.SecretAccessKey')
      export AWS_SESSION_TOKEN=$(echo $output | jq -r '.Credentials.SessionToken')

      aws s3 sync /var/backup/postgresql s3://windmill-fb9bb14a273e85f2/postgresql-backup
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

  # Define the timer for the sync service
  systemd.timers.sync-postgresql-backup-timer = {
    description = "Timer to sync PostgreSQL backup to S3 every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    unitConfig = {
      Unit = "sync-postgresql-backup.service";
    };
  };

  services.postgresqlBackup = {
    enable = true;
    databases = [ "windmill" ];
  };

  # timer for postgresql backup service to run every minute


    # Restore mbcontrol from S3
  systemd.services.restore = {
    description = "Restore database from S3";
    wantedBy = [ "multi-user.target" ];
    requires = [ "postgresql.service" ];
    path = [ pkgs.awscli2 pkgs.postgresql pkgs.gzip pkgs.jq ];
    environment = {
      AWS_ACCESS_KEY_ID = (pkgs.lib.removeSuffix "\n" (builtins.readFile /aws-access-key-id));
      AWS_SECRET_ACCESS_KEY = (pkgs.lib.removeSuffix "\n" (builtins.readFile /aws-secret-access-key));
      AWS_REGION = "us-west-2";
    };
    script = ''
      # assume role arn:aws:iam::150301572911:role/windmill 
      # Assume the role and capture the output in a variable
      output=$(aws sts assume-role \
          --role-arn arn:aws:iam::150301572911:role/windmill \
          --role-session-name MySession)

      # Extract the temporary credentials from the output
      export AWS_ACCESS_KEY_ID=$(echo $output | jq -r '.Credentials.AccessKeyId')
      export AWS_SECRET_ACCESS_KEY=$(echo $output | jq -r '.Credentials.SecretAccessKey')
      export AWS_SESSION_TOKEN=$(echo $output | jq -r '.Credentials.SessionToken')

      aws s3 cp s3://windmill-fb9bb14a273e85f2/postgresql-backup/windmill.sql.gz /var/backup/postgresql/windmill.sql.gz
      gunzip -f /var/backup/postgresql/windmill.sql.gz
      # exec on db ALTER DATABASE mbcontrol OWNER TO youruser;
      systemctl stop windmill-worker windmill-worker-native windmill-server.service 
      psql -U postgres -c "DROP DATABASE IF EXISTS windmill"
      psql -U postgres -c "CREATE DATABASE windmill"
      psql -U postgres -c "ALTER DATABASE windmill OWNER TO windmill"
      psql -U windmill -d windmill -f /var/backup/postgresql/windmill.sql
    '';
    serviceConfig = {
      Type = "oneshot";

    };
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
