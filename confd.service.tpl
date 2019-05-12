[Unit]
Description=awscli
After=docker.service
After=network.target
Requires=docker.service

[Service]
Type=oneshot
ExecStartPre=-/usr/bin/docker stop confd
ExecStartPre=-/usr/bin/docker rm confd
ExecStartPre=/usr/bin/docker pull tdub17/confd:latest
ExecStart=/usr/bin/docker run -dit --name confd --mount type=bind,source=/etc/confd/templates/myconfig.conf.tmpl,target=/etc/confd/templates/myconfig.conf.tmpl --mount type=bind,source=/etc/confd/conf.d/myconfig.toml,target=/etc/confd/conf.d/myconfig.toml -v /tmp/:/tmp/ tdub17/confd
RemainAfterExit=true
StandardOutput=journal

[Install]
WantedBy=multi-user.target
