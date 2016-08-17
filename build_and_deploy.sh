#!/usr/bin/env sh
set -e

SITE_ENV="$1"
USER_AT_REMOTE_DIRECTORY="$2"

if [ -z "$USER_AT_REMOTE_DIRECTORY" ] && [ "$SITE_ENV" != "local" ] && [ "$SITE_ENV" != "production" ] && [ "$SITE_ENV" != "staging" ]
then
  echo "./build_and_deploy.sh [production|staging|local] [user@hostname:/example_directory]"
  exit 1
fi

log() {
  echo ""
  echo "# $1"
  echo "================================================================================"
}

build() {
  log "building client side assets..."
  ./node_modules/gulp/bin/gulp.js build

  log "building markup..."
  ./build_html.rb

  log "copying count.json..."
  cp scripts/count.json build/site/scripts/count.json
}

deploy() {
  # deploy but exclude deletion of counter
  log "deploying... ($USER_AT_REMOTE_DIRECTORY)"
  rsync -av build/site/ "$USER_AT_REMOTE_DIRECTORY" --force --delete --exclude=counter
}

clean() {
  log "cleaning... (deleting ./public)"
  rm -rf build/
}

# just build locally (./public)
if [ "$SITE_ENV" = "local" ]
then
  build
  exit 0
fi

# default build and deploy
build && deploy && clean
