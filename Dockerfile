FROM ruby:4.0-slim

ENV APP_DIR=/app \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH="/bundle" \
    RACK_ENV=production

RUN --mount=type=cache,target=/var/cache/apt \
     apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    tzdata

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

ENV PORT=4567
EXPOSE 4567

CMD ["bundle", "exec", "ruby", "src/main.rb"]
