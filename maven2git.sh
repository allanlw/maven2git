#!/bin/bash

set -euo pipefail

shopt -u dotglob # do not include hidden files in globs

# getopt parsing (any number of positional arguments, or --prefix which takes one argument)
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --prefix)
            PREFIX="$2"
            shift
            shift
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [ -z "$PREFIX" ] && [ ${#POSITIONAL[@]} -eq 0 ]; then
    echo "Usage: $0 [--prefix PREFIX] [TARGET...]"
    exit 1
fi

if [ -n "$PREFIX" ] && [ ${#POSITIONAL[@]} -gt 0 ]; then
    echo "Error: Cannot specify both --prefix and TARGET"
    exit 1
fi

required_tools=(git gsutil unzip)
for tool in "${required_tools[@]}"; do
  if ! command -v $tool &> /dev/null; then
    echo "Error: $tool is not installed"
    exit 1
  fi
done

cache_dir="./cache"
repos_dir="./repos"
mirror="gs://maven-central-asia/maven2"

if [ -n "$PREFIX" ]; then
    prefix_dir=$(echo $PREFIX | tr ':.' '/')
    gsutil -m rsync -r "$mirror/$prefix_dir" "$cache_dir/$prefix_dir"
    target_dirs=($(find "$cache_dir/$prefix_dir" | grep -E 'maven-metadata\.xml$' | sed -E 's$^'$cache_dir'/(.*)/maven-metadata.xml$\1$'))
    echo "$target_dirs"
else
    target_dirs=()
    for target in "${POSITIONAL[@]}"; do
        target_dir=$(echo $target | tr ':.' '/')
        target_dirs+=("$target_dir")
    done
fi


for target_dir in "${target_dirs[@]}"; do
    artifactid=$(basename $target_dir)

    mkdir -p "$cache_dir/$target_dir"

    gsutil -m rsync -r "$mirror/$target_dir" "$cache_dir/$target_dir"

    # Note: versions are already sorted in maven-metadata.xml
    versions=$(grep -oP "<version>.*</version>" "$cache_dir/$target_dir/maven-metadata.xml" | sed -e 's/<version>\(.*\)<\/version>/\1/')

    out_repo="$repos_dir/$target_dir"
    if [ -d "$out_repo" ]; then
        echo "Error: Repository already exists at $out_repo"
        exit 1
    fi
    mkdir -p "$out_repo"
    git init "$out_repo"

    for version in $versions; do
        echo "Processing $artifactid:$version"

        rm -fr "$out_repo/"*
        
        base_path="$cache_dir/$target_dir/$version/$artifactid-$version"
        cp -r "$base_path.pom" "$out_repo/pom.xml"
        if [ -f "$base_path-sources.jar" ]; then
            mkdir -p "$out_repo/sources"
            unzip -q "$base_path-sources.jar" -d "$out_repo/sources"
        fi
        if [ -f "$base_path-javadoc.jar" ]; then
            mkdir -p "$out_repo/javadoc"
            unzip -q "$base_path-javadoc.jar" -d "$out_repo/javadoc"
        fi
        git -C "$out_repo" add .
        git -C "$out_repo" commit -q -m "Add $artifactid-$version"
    done

    echo "Done. Repository is at $out_repo"
done
