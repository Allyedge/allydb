# [AllyDB](https://allydb.vercel.app/)

[![Made with Elixir](https://forthebadge.com/images/badges/made-with-elixir.svg)](https://elixir-lang.org/)

[![Latest Docker Image Version](https://img.shields.io/docker/v/allyedge/allydb?color=lightblue&label=latest%20docker%20image%20version&sort=semver&style=for-the-badge)](https://hub.docker.com/r/allyedge/allydb)

[![License](https://img.shields.io/github/license/allyedge/allydb?style=for-the-badge)](https://github.com/Allyedge/allydb/blob/main/LICENSE)

[![Documentation](https://allydb.vercel.app/visit-documentation.svg)](https://allydb.vercel.app/)

An in-memory database similar to Redis, built using Elixir.

## Roadmap

`(?)` means that the item is an idea, but it is unclear how it will be implemented, or how the implementation will look like.

`(!)` means that the item will probably be implemented in the future, but it is not a priority.

## Features Roadmap

- [x] Basic key value store
- [x] Lists
- [x] Usage Guide
- [x] Persistence
- [x] Hashes
- [x] Sets
- [ ] Sorted Sets (!)
- [ ] Pub/Sub (!)
- [ ] Clustering/Distribution (?)
- [ ] Custom database and persistence settings (?)

## Performance Roadmap

- [ ] Better usage of OTP (?)
- [ ] Better usage of ETS (?)
- [ ] Optimize persistence (?)
- [ ] Rust NIFs for heavy operations (?)

## Development Roadmap

- [ ] Testing
- [ ] Improve code quality
- [ ] Extract repetitive code into functions

## Usage

### Environment Variables

| Name                       | Description                                          | Default      |
| -------------------------- | ---------------------------------------------------- | ------------ |
| `ALLYDB_PORT`              | The port on which the server will listen             | `4000`       |
| `PERSISTENCE_LOCATION`     | The location where the database will be persisted    | `allydb.tab` |
| `PERSISTENCE_INTERVAL`     | The interval at which the database will be persisted | `3000`       |
| `LOG_PERSISTENCE_LOCATION` | The location where the log file will be stored       | `allydb.log` |

### Installation

#### Using Docker

You can use the docker image to run the database.

```sh
> docker pull allyedge/allydb

> docker run -p 4000:4000 allyedge/allydb
```

#### Build from source

You can also build the project from source.

```sh
> git clone https://github.com/Allyedge/allydb

> cd allydb

> mix deps.get

> mix compile

> mix release --env=prod

> _build/prod/rel/allydb/bin/allydb start
```

## Documentation

You can find the documentation [here](https://allydb.vercel.app).

## Example Usage

### Basic Key Value Store

```sh
> SET hello world
world

> GET hello
world

> DEL hello
hello
```

### Lists

```sh
> lpush list 1
1

> lpush list 2
2

> lpush list 3
3

> lpop list
3
```

### Hashes

```sh
> hset user id 1 name john age 20
3

> hget user name
john

> hgetall user
age
20
id
1
name
john

> hdel user age
1
```

## Persistence

The database is persisted to an append only log file. This means that the database can be restored to a previous state.

The database is also persisted on a regular interval, in case something happens to the log file.

The interval can be configured using the `PERSISTENCE_INTERVAL` environment variable. The default value is `3000ms`.

## License

AllyDB is licensed under the Apache License 2.0. You can find the license [here](https://github.com/Allyedge/allydb/blob/main/LICENSE).
