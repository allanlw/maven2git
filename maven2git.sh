#!/bin/bash

set -euo pipefail

shopt -u dotglob # do not include hidden files in globs

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 PREFIX"
    exit 1
fi

PREFIX="$1"

required_tools=(git gcloud unzip)
for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" &> /dev/null; then
    echo "Error: $tool is not installed"
    exit 1
  fi
done

cache_dir="./cache"
repos_dir="./repos"
mirror="gs://maven-central-asia/maven2"

RSYNC_CMD="gcloud storage rsync -r --gzip-in-flight=.xml,.pom --exclude=.*\.(asc|sha1|md5)$"

prefix_dir=$(echo "$PREFIX" | tr ':.' '/')
$RSYNC_CMD "$mirror/$prefix_dir" "$cache_dir/$prefix_dir"
mapfile -t target_dirs < <(find "$cache_dir/$prefix_dir" | grep -E 'maven-metadata\.xml$' | sed -E 's$^'$cache_dir'/(.*)/maven-metadata.xml$\1$')

out_repo="$repos_dir/$prefix_dir"
if [ -d "$out_repo" ]; then
    echo "Error: Repository already exists at $out_repo"
    exit 1
fi
mkdir -p "$out_repo"
git init "$out_repo"
for target_dir in "${target_dirs[@]}"; do
    artifactid=$(basename "$target_dir")

    out_path="$out_repo/$target_dir"
    mkdir -p "$out_path"
    git checkout --orphan "$target_dir"

    versions=$(grep -oP "<version>.*</version>" "$cache_dir/$target_dir/maven-metadata.xml" | sed -e 's/<version>\(.*\)<\/version>/\1/')

    for version in $versions; do
        echo "Processing $artifactid:$version"

        rm -rf "${out_repo:?}/"*

        base_path="$cache_dir/$target_dir/$version/$artifactid-$version"
        cp -r "$base_path.pom" "$out_repo/pom.xml"
        if [ -f "$base_path-sources.jar" ]; then
            mkdir -p "$out_repo/sources"
            unzip -q "$base_path-sources.jar" -d "$out_path/sources"
        fi
        if [ -f "$base_path-javadoc.jar" ]; then
            mkdir -p "$out_repo/javadoc"
            unzip -q "$base_path-javadoc.jar" -d "$out_path/javadoc"
        fi
        git -C "$out_repo" add .
        git -C "$out_repo" commit -q -m "Add $artifactid-$version"
    done

    echo "Done with $out_repo"
done

git -C "$out_repo" checkout --orphan main
git merge "${target_dirs[@]}"
