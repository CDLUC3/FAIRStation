# syntax=docker/dockerfile:1

FROM ruby:4.0.6-slim-trixie AS base

WORKDIR /rails

# mysql2 links against Debian's MariaDB client library, which speaks MySQL.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y ca-certificates libmariadb3 tzdata && \
    rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential default-libmysqlclient-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock .ruby-version ./
# Use the lockfile's Bundler version rather than the image's default version.
RUN BUNDLER_VERSION="$(ruby -e 'puts File.read("Gemfile.lock").split("BUNDLED WITH").last.strip')" && \
    gem install bundler --version "$BUNDLER_VERSION" --no-document && \
    bundle "_${BUNDLER_VERSION}_" install && \
    rm -rf /usr/local/bundle/cache

COPY . .
# This build-only value is not persisted as an environment variable or secret.
RUN SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile && \
    rm -rf tmp log

FROM base AS runtime

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash rails && \
    mkdir -p log storage tmp/pids tmp/cache && \
    chown -R rails:rails log storage tmp

USER rails:rails
EXPOSE 3000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["bin/rails", "server", "--binding", "0.0.0.0", "--port", "3000"]
