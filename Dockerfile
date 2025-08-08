FROM gliderlabs/herokuish:latest-22

ENV STACK=heroku-22

WORKDIR /app
COPY . .

RUN /bin/herokuish buildpack build

CMD ["/bin/herokuish", "procfile", "start", "web"]
