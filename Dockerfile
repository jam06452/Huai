ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.5.0.1
ARG DEBIAN_VERSION=trixie-20260518-slim
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y \
  && apt-get install -y build-essential git \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN apt-get update -y \
  && apt-get install -y build-essential git curl \
  && curl -LsSf https://astral.sh/uv/install.sh | sh \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

  ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

RUN mkdir config
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

COPY priv priv
COPY assets assets
COPY lib lib
RUN mix compile
RUN mix assets.deploy

# Build release
COPY config/runtime.exs config/
COPY rel rel
RUN mix release

FROM ${RUNNER_IMAGE}

RUN apt-get update -y \
  && apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates curl \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/_build/prod/rel/huai ./

USER nobody

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:${PORT:-4000}/health || exit 1

EXPOSE 4000

CMD ["/app/bin/server"]
