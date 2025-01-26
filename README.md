# maven2git

This repo contains a bash script (`maven2git.sh`) that will create a git repository from the javadoc and sources for all versions of a maven artifact.

To use it, you must have `gsutil` installed because it pulls from the [Google GCS Maven Central Mirror](https://storage-download.googleapis.com/maven-central/index.html).

Usage is: `./maven2git.sh <groupId>:<artifactId>`.

The cache of downloaded packages will be created in `./cache` and the output repos will be stored in `./repos`.