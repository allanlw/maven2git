# maven2git

This repo contains a bash script (`maven2git.sh`) that will create a git repository from the javadoc and sources for all versions of a maven artifact.

To use it, you must have `gcloud` installed because it pulls from the [Google GCS Maven Central Mirror](https://storage-download.googleapis.com/maven-central/index.html).

Usage is: `./maven2git.sh <groupId>:<artifactId>`. Multiple arguments can be specified.

The script takes one argument --prefix (or -p) which takes an argument that will be interpreted as a prefix and parse all the artifacts that match that prefix. For example, `--prefix com.google` will process all artifacts in `com.google` or any group that starts with `com.google`.

The cache of downloaded packages will be created in `./cache` and the output repos will be stored in `./repos`.