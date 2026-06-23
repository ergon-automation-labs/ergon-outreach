FROM ergon-automation-labs/ergon-builder:1.0.0 as builder

WORKDIR /app
RUN apk add --no-cache build-base git elixir
COPY mix.exs mix.lock ./
RUN mix local.hex --force && mix local.rebar --force && mix deps.get --only prod

COPY . .
RUN mix compile --prod && mix release

# Runtime
FROM ergon-automation-labs/ergon-builder:base

COPY --from=builder /app/_build/prod/rel/outreach_bot /app/bin/

ENV MIX_ENV=prod
ENV NATS_SERVERS=nats://nats:4222
ENV DB_HOST=postgres
ENV DB_PORT=5432
ENV DB_NAME=bot_army_outreach
ENV DB_USER=postgres
ENV DB_PASSWORD=postgres

CMD ["outreach_bot", "start"]
