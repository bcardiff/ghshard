# ghshard

Helper for crystal shards that are hosted in github.

## Features

* Publish docs in gh-pages
* Handle redirection in docs (latest -> 0.3, 0.3 -> 0.3.6)

## Installation

```
$ git clone https://github.com/bcardiff/ghshard.git
$ cd ghshard
$ shards build
# keep ./bin/ghshard executable where you can find it
```

## Usage

You favorite shard is read for a proper presentation to the world.

* You have wrote docs
* You are satisfied with `crystal docs` result
* You have tagged a version of the shard, eg: `0.1.0`
* You want to upload those docs to `gh-pages`

```
$ cd path/to/shard
$ ghshard docs:publish
```

It will create the `gh-pages` branch and submit the result of `crystal docs` to `/api/0.1.0`.

You can add redirections:

* from `/api/0.1/*` to `/api/0.1.0/*`

```
$ ghshard docs:redirect 0.1 0.1.0
```

* from `/api/latest/*` to `/api/0.1/*`

```
$ ghshard docs:redirect latest 0.1
```

When you are ready to release 0.1.1 you will need to:

```
$ ghshard docs:publish
$ ghshard docs:redirect 0.1 0.1.1
```

When you are ready to release 0.2.0 you will need to:

```
$ ghshard docs:publish
$ ghshard docs:redirect 0.2 0.2.0
$ ghshard docs:redirect latest 0.2
```

## Roadmap

* Add helper to bump versions

```
$ ghshard bump
current: 0.1.9
  a. patch 0.1.10
  b. minor 0.2.0
  c. mayor 1.0.0
choose [a-c]: ...
```

* Add helper to publish (tag+annotate+push+docs)
* Add options to avoid default commit/push behaviour
* document options


## Contributing

1. Fork it ( https://github.com/bcardiff/ghshard/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [bcardiff](https://github.com/bcardiff) Brian J. Cardiff - creator, maintainer
