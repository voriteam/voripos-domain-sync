# VoriPOS Domain Sync

Domain data (e.g., products, tax rates) is data that is mutated on Vori's servers (typically by Dashboard users). This
data is consumed by the POS to facilitate shopper checkout. We use [LiteFS Cloud](https://fly.io/docs/litefs/) to
automatically replicate a SQLite database generated by Vori.

LiteFS requires a virtual filesystem that does not run on macOS, so we run it in a Docker container. Things get more
complicated as we need to make the data on the virtual filesystem in the Docker container visible to the host. We cannot
simply expose a host volume because it is not compatible with the virtual filesystem. Thus, we have a somewhat-hacky
solution. `fswatch` polls the directory where LiteFS tracks internal state, and copies the database to a shared host
volume. This is not ideal, but it works well enough for our purposes.

## Installation
This service is distributed via Homebrew.

```shell
brew tap voriteam/voripos
brew install voripos-domain-sync
brew services start voripos-domain-sync
```

## Local development
A LiteFS Cloud token is required to set up syncing. This can be pulled from Fly.io, or ask
in [#engineering](https://voriworkspace.slack.com/archives/CS49ASVEU).

Add the token to the `.env` file, and start Docker Compose with:

```shell
docker compose up
```

This will connect to LiteFS Cloud and download the database to `~/Library/Containers/com.vori.VoriPOS/Data/Library/Application Support/Domain.sqlite3`.
When the database is synced, a query is run to output the DB metadata and row counts. If you don't see this after a few
seconds, something may be wrong with the configuration.

You may see other database names when connecting to the `vori-demo` cluster. These can be ignored.
LiteFS Cloud does not currently support complete database deletion, and we aren't copying these to the host volume.

Need to start from scratch? Kill the containers and restart.

```shell
docker compose down
```

## Distribution
The Docker image is pulled by the POS machines. If you change the image, push it!

You may need to set up a builder:

```shell
docker buildx create --name mybuilder --bootstrap --use
```

This command will build _and push_ the images for both dev and production:

```shell
docker buildx build --platform linux/amd64,linux/arm64 -t us-docker.pkg.dev/vori-dev/pos/domain-data:latest -t us-docker.pkg.dev/vori-1bdf0/pos/domain-data:latest --push .
```

### Homebrew
1. Update `VORIPOS_DOMAIN_SYNC_VERSION`.
2. Create a release on GitHub.
3. Follow the instructions at https://github.com/voriteam/homebrew-voripos to update the tap with the latest version.
