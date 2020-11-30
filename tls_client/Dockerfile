FROM elixir:1.11.2-alpine
ENV LANG=en_US.UTF-8
RUN adduser -D -G users -u 1000 user

WORKDIR /app
COPY ./ .

RUN chown -R user:users /app

USER user

RUN mix local.hex --force && \
    mix local.rebar --force && \
    MIX_ENV=prod mix compile

CMD MIX_ENV=prod mix run --no-halt