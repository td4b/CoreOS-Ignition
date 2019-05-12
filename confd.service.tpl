[Unit]
Description=confd service
After=docker.service
After=network.target
Requires=docker.service

[Service]
Type=oneshot
ExecStartPre=-/usr/bin/docker stop confd
ExecStartPre=-/usr/bin/docker rm confd
ExecStartPre=/usr/bin/docker pull tdub17/confd:latest
ExecStart=/usr/bin/docker run -dit --mount type=bind,source=/etc/confd/templates/login.conf.tmpl,target=/etc/confd/templates/login.conf.tmpl --mount type=bind,source=/etc/confd/conf.d/myconfig.toml,target=/etc/confd/conf.d/myconfig.toml -v /root/.docker/:/root/.docker/ tdub17/confd
RemainAfterExit=true
StandardOutput=journal

[Install]
WantedBy=multi-user.target
