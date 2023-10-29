{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.rke2;
  settingsFormat = pkgs.formats.yaml { };
  configFile =
    if cfg.configFile != null then
      cfg.configFile
    else if cfg.settings != { } then
      settingsFormat.generate "rke2-config.yaml" cfg.settings
    else
      null;
in
{
  options.services.rke2 = {
    enable = mkEnableOption (lib.mdDoc "rke2");

    package = lib.mkPackageOptionMD pkgs "rke2" { };

    role = mkOption {
      description = lib.mdDoc ''
        Whether rke2 should run as a server or agent.

        If it's a server:

        - By default it also runs workloads as an agent.
        - Starts by default as a standalone server using an embedded sqlite datastore.
        - Configure `serverAddr` to join an already-initialized HA cluster.

        If it's an agent:

        - `serverAddr` is required.
      '';
      default = "server";
      type = types.enum [ "server" "agent" ];
    };

    serverAddr = mkOption {
      type = types.str;
      description = lib.mdDoc ''
        The rke2 server to connect to.

        Servers and agents need to communicate each other. Read
        [the networking docs](https://rancher.com/docs/rke2/latest/en/installation/installation-requirements/#networking)
        to know how to configure the firewall.
      '';
      example = "https://10.0.0.10:6443";
      default = "";
    };

    tokenFile = mkOption {
      type = types.nullOr types.path;
      description = lib.mdDoc "File path containing rke2 token to use when connecting to the server.";
      default = null;
    };

    extraFlags = mkOption {
      description = lib.mdDoc "Extra flags to pass to the rke2 command.";
      type = types.listOf types.str;
      default = [ ];
      example = [ "--no-deploy" "traefik" "--cluster-cidr" "10.24.0.0/16" ];
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      description = lib.mdDoc ''
        File path containing environment variables for configuring the rke2 service in the format of an EnvironmentFile. See systemd.exec(5).
      '';
      default = null;
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = lib.mdDoc "File path containing the rke2 YAML config. This is useful when the config is generated (for example on boot).";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/rancher/rke2";
      description = "Folder to hold state";
    };

    settings = mkOption {
      type = settingsFormat.type;
      description = lib.mdDoc "Configuration settings";
      default = { };
    };

    manifests = mkOption {
      type = types.attrsOf types.path;
      description = "Files to symlink into the manifests folder";
      default = { };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.role == "agent" -> (configFile != null || cfg.serverAddr != "");
        message = "serverAddr or configFile (with 'server' key) should be set if role is 'agent'";
      }
      {
        assertion = cfg.role == "agent" -> configFile != null || cfg.tokenFile != null;
        message = "tokenFile or configFile (with 'token-file' keys) should be set if role is 'agent'";
      }
    ];

    # Convenient utilities
    environment.systemPackages = [
      config.services.rke2.package
      pkgs.kubectl
      pkgs.kubernetes-helm
    ];

    boot.kernelModules = [
      "br_netfilter"
      "iptable_filter"
      "iptable_nat"
      "overlay"
    ];

    # Apply CIS Hardening - https://docs.rke2.io/security/hardening_guide
    boot.kernel.sysctl = {
      "kernel.panic" = 10;
      "kernel.panic_on_oops" = 1;
      "vm.overcommit_memory" = 1;
      "vm.panic_on_oom" = 0;
    };

    # The RKE2 server needs port 6443 and 9345 to be accessible by other nodes in the cluster.

    # All nodes need to be able to reach other nodes over UDP port 8472 when Flannel VXLAN is used.

    # If you wish to utilize the metrics server, you will need to open port 10250 on each node.

    systemd.services.rke2 = {
      description = "rke2 service";
      after = [ "firewall.service" "network-online.target" ];
      wants = [ "firewall.service" "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path =
        optional config.boot.zfs.enabled config.boot.zfs.package ++ [
          pkgs.iptables
          pkgs.mount
        ];
      serviceConfig = {
        Type = if cfg.role == "agent" then "exec" else "notify";
        KillMode = "process";
        Delegate = "yes";
        Restart = "always";
        RestartSec = "5s";
        LimitNOFILE = 1048576;
        LimitNPROC = "infinity";
        LimitCORE = "infinity";
        TasksMax = "infinity";
        EnvironmentFile = cfg.environmentFile;
        # TODO: load image
        # ExecStartPre = "${pkgs.coreutils}/bin/install -D ${cfg.package.passthru.images} /var/lib/rancher/rke2/agent/images/";
        ExecStartPre = pkgs.writeShellScript "rke2-exec-start-pre" (''
          set -euo pipefail

          # Remove old nix manifests
          ${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}/server/manifests
          ${pkgs.findutils}/bin/find ${cfg.dataDir}/server/manifests -type l -delete
        ''
        + (lib.optionalString (cfg.role == "server" && cfg.manifests != { }) ''
          # Link all the manifests
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: file:
            "ln -s ${file} ${cfg.dataDir}/server/manifests/${name}"
          ) cfg.manifests)}
        ''));
        ExecStart = escapeShellArgs (
          [
            (getExe cfg.package)
            cfg.role
            "--data-dir"
            cfg.dataDir
          ]
          ++ (optionals (configFile != null) [ "--config" configFile ])
          ++ (optionals (cfg.serverAddr != "") [ "--server" cfg.serverAddr ])
          ++ (optionals (cfg.tokenFile != null) [ "--token-file" (toString cfg.tokenFile) ])
          ++ cfg.extraFlags
        );
      };
    };
  };
}
