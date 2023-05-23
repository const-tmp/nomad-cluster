#!/usr/bin/env zsh
find . -type d | sed -E -e '/\.idea/d' -e '/\.git/d' -e '/\.terraform/d' | while read d
do
  pushd "$d" || exit
  terraform fmt
  popd || exit
done
