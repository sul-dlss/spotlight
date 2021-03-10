ARG RUBY_VERSION=2.7.2
FROM ruby:$RUBY_VERSION-alpine

ENV SPOTLIGHT_ENGINE_PATH /spotlight/engine
ENV SPOTLIGHT_GEM /spotlight/engine
ENV RAILS_QUEUE inline

RUN apk --no-cache upgrade && \
  apk add --no-cache \
  bash \
  build-base \
  git \
  imagemagick \
  libxml2-dev \
  libxslt-dev \
  nodejs-current \
  postgresql-dev \
  sqlite-dev \
  tini \
  tzdata \
  yarn

RUN addgroup --gid 10001 --system spotlight && \
  adduser --uid 10000 --system \
  --ingroup spotlight --home /spotlight spotlight

RUN gem update bundler
RUN gem install --no-document rails -v '< 6.1'

COPY . /spotlight/engine
RUN cd /spotlight/engine && bundle install --jobs "$(nproc)"

WORKDIR /spotlight/app
RUN mkdir -p /spotlight/app
RUN rails new . --force --template=../engine/template.rb

RUN chown -R 10000:10001 /spotlight
USER spotlight

RUN DB_ADAPTER=nulldb DATABASE_URL='postgresql://fake' bundle exec rake assets:precompile

ENTRYPOINT ["/sbin/tini", "--", "/spotlight/engine/bin/docker-entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:3000"]
