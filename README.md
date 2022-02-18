docker build . --tag zulip-compose:latest
docker run --rm  -v //var/run/docker.sock:/var/run/docker.sock zulip-compose:latest