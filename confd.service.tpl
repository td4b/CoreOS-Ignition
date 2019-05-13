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
ExecStart=/usr/bin/docker run -dit -v /etc/confd/:/etc/confd/ -v /root/.docker/:/root/.docker/ tdub17/confd
RemainAfterExit=true
StandardOutput=journal

[Install]
WantedBy=multi-user.target
