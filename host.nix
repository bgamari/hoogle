{ hoogle, domain, cores ? 4 }:
{ config, pkgs, ... }:

# The Plan:
# Hoogle serves on a uniquely-named UNIX domain socket which we
# configure nginx to forward to via the nginxConf configuration
# fragment. The Hoogle database is periodically updated by
# rotate-hoogle.service which generates a new Hoogle database,
# starts a new hoogle server, updates the nginx configuration
# and shuts down the old server.

let
  hoogleRun = "/run/hoogle";
  nginxConf = "${hoogleRun}/nginx.conf";
in
{
  systemd.timers."rotate-hoogle" = {
    description = "Rotate Hoogle instance";
    timerConfig.Unit = "rotate-hoogle.service";
    timerConfig.OnCalendar = "hourly";
  };

  systemd.services."rotate-hoogle" = {
    description = "Rotate Hoogle instance";
    wantedBy = [ "multi-user.target" ];
    script = ''
      n="$(date +%Y%m%d-%H%M%S)"
      systemctl start "hoogle@$n"
      echo "server unix:/run/hoogle-$n/socket" > ${nginxConf}
      systemctl reload nginx.service
      sleep 1
      # Stop old instance
      systemctl list-units --no-legend --plain 'hoogle@*' | awk "!/hoogle@$n/ {print \$1}" | xargs systemctl stop
    '';
  };

  systemd.services."hoogle@" = {
    preStart = ''
      hoogle generate --database=haskell.hoo +RTS -N${toString cores} -RTS
      hoogle test --database=haskell.hoo
    '';
    script = "hoogle server --database=haskell.hoo --socket=socket --links +RTS -T -N${toString cores} -RTS";
    path = [ hoogle ];
    serviceConfig.RuntimeDirectory = "hoogle-%i";
    serviceConfig.RootDirectory = "/run/hoogle-%i";
    serviceConfig.BindReadOnlyPaths = [
      # mount the nix store read-only
      "/nix/store"
      # getAppUserDataDirectory needs getUserEntryForID
      "/etc/passwd"
    ];

  };

  systemd.tmpfiles.rules =
    [ "f ${nginxConf} 0755 nginx nginx -"
    ];

  services.nginx = {
    upstreams.hoogle.extraConfig = ''
      include ${nginxConf}
    '';
    virtualHosts.${domain} = {
      locations."/" = {
        proxyPass = "http://hoogle";
      };
      addSSL = true;
    };
  };
}

