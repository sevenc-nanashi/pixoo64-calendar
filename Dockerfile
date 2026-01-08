FROM ruby:4.0-slim

ENV APP_DIR=/app \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH="/bundle" \
    RACK_ENV=production

RUN --mount=type=cache,target=/var/cache/apt \
     apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    cron \
    curl \
    tzdata

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

COPY docker/entrypoint.sh /usr/local/bin/entrypoint
COPY docker/update.sh /usr/local/bin/pixoo64-update
RUN chmod +x /usr/local/bin/entrypoint /usr/local/bin/pixoo64-update

ENV PORT=4567
EXPOSE 4567

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["bundle", "exec", "ruby", "src/main.rb"]
