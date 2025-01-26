#!/bin/bash

set -xeuo pipefail

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
prefix_dir=$(echo "$PREFIX" | tr ':.' '/')
out_repo="$repos_dir/$prefix_dir"
RSYNC_CMD="gcloud storage rsync -r --gzip-in-flight=.xml,.pom --exclude=.*\.(asc|sha1|md5)$"

if [ -d "$out_repo" ]; then
    echo "Error: Repository already exists at $out_repo"
    exit 1
fi
mkdir -p "$out_repo"
git init "$out_repo"
GIT="git -C $out_repo"

$GIT config gc.auto 0

#$RSYNC_CMD "$mirror/$prefix_dir" "$cache_dir/$prefix_dir"
mapfile -t target_dirs < <(find "$cache_dir/$prefix_dir" | grep -E 'maven-metadata\.xml$' | sed -E 's$^'$cache_dir'/(.*)/maven-metadata.xml$\1$')

for target_dir in "${target_dirs[@]}"; do
    artifactid=$(basename "$target_dir")
    out_path="$repos_dir/$target_dir"

    $GIT checkout --orphan "$target_dir"
    rm -rf "${out_repo:?}/"*
    mkdir -p "$out_path"

    versions=$(grep -oP "<version>.*</version>" "$cache_dir/$target_dir/maven-metadata.xml" | sed -e 's/<version>\(.*\)<\/version>/\1/')

    if [ -z "$versions" ]; then
        echo "Warning: No versions found for $artifactid in $target_dir"
        continue
    fi

    for version in $versions; do
        echo "Processing $artifactid:$version"

        rm -rf "${out_path:?}/"*

        base_path="$cache_dir/$target_dir/$version/$artifactid-$version"
        cp -r "$base_path.pom" "$out_path/pom.xml"
        if [ -f "$base_path-sources.jar" ]; then
            mkdir -p "$out_path/sources"
            unzip -q "$base_path-sources.jar" -d "$out_path/sources"
        fi
        if [ -f "$base_path-javadoc.jar" ]; then
            mkdir -p "$out_path/javadoc"
            unzip -q "$base_path-javadoc.jar" -d "$out_path/javadoc"
        fi
        $GIT add .
        $GIT commit -q -m "Add $artifactid-$version" --allow-empty
    done


    $GIT gc
    echo "Done with $target_dir"
done

$GIT checkout --orphan main
$GIT merge "${target_dirs[@]}"
$GIT config gc.auto 0
$GIT gc --aggressive
