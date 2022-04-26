This is a Ruby (with Rust backend) client for the [CipherStash encrypted, searchable data store](https://cipherstash.com).

> # !!! CURRENT STATUS !!!
>
> This client is currently extremely experimental and incomplete.
> While we're happy for you to use it, please don't expect everything to work perfectly, nor for all features of other CipherStash clients to be available.
>
> At present, the following things should work:
>
> * Creating a client
> * Using environment variables to configure the client
> * Using a profile to configure the client, as long as the cached access token is valid
> * Federating to AWS to access KMS using an access token
> * Loading collections created with stash-cli
> * Inserting, upserting, and deleting data
> * Retrieving data by ID that was written by StashRB
> * Querying data written by StashRB


# Installation

As `cipherstash-client` uses a Rust-based library (`ore-rs`) for its underlying cryptography, installation is a bit trickier than most gems.

## Pre-requisites

### Rust

To build the dependencies of `cipherstash-client`, you must have at least Rust 1.59 installed.
If you are on an arm64 machine (M1 Mac, for example) you will need to be running a recent Rust nightly.
We'll have better docs on how to do that in the future; for now, if you don't know how to do that, this gem *probably* isn't for you just yet.


## Da gem!  Da gem!

So, if that's all good, you can install it as a gem:

    gem install cipherstash-client

There's also the wonders of [the Gemfile](http://bundler.io):

    gem 'cipherstash-client'

If you're the sturdy type that likes to run from git:

    rake install

Or, if you've eschewed the convenience of Rubygems entirely, then you
presumably know what to do already.


# Usage

## Getting Off The Ground

First off, you need to load the library and a client:

```ruby
require "cipherstash/client"

stash = CipherStash::Client.new
```

This will pick up your configuration from the default profile; if you want to specify a different profile to load:

```ruby
stash = CipherStash::Client.new(profileName: "bob")
```

Alternately, you can also set all configuration via environment variables.
See [the CipherStash Client Configuration reference](https://docs.cipherstash.com/reference/client-configuration.html) for more details.


## Collections

All data in CipherStash is stored in [collections](https://docs.cipherstash.com/reference/glossary.html#collection).
You can load all collections:


```ruby
stash.collections  # => [<collection>, <collection>, ...]
```

Or you can load a single collection, if you know its name:

```ruby
collection = stash.collection("movies")
```


## Inserting Records

To insert a [record](https://docs.cipherstash.com/reference/glossary.html#record):

```ruby
collection.insert({ foo: "bar", baz: "wombat" })
```


## Querying

A query is a set of constraints applied to the records in a collection.
Constraints are defined in a block passed to `Collection#query`, like so:

```ruby
collection.query do |movies|
  movies.exactTitle("Star Trek: The Motion Picture")
  movies.year.gt(1990.0)
end
```

Multiple constraints will be `AND`ed together, and so the above query will not return any records because "Star Trek: The Motion Picture" was made before 1990.


## API Documentation

The [auto-generated API documentation](https://rubydoc.info/gems/cipherstash-client) should provide complete documentation of all public methods and classes.



# Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md).


# Licence

Unless otherwise stated, everything in this repo is covered by the following
copyright notice:

    Copyright (C) 2022  CipherStash Inc.

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License version 3, as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
