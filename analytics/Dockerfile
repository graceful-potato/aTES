FROM ruby:3.2.2-alpine3.17

RUN apk --update add build-base tzdata postgresql-dev postgresql-client bash curl

RUN mkdir -p /app

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

ENTRYPOINT [ "./app-entrypoint.sh" ]
