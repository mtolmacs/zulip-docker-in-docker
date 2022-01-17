FROM docker/compose:latest

COPY ./docker-compose.yml /

CMD [ "up" ]