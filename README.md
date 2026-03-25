# philiprehberger-dot_access

[![Tests](https://github.com/philiprehberger/rb-dot-access/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-dot-access/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-dot_access.svg)](https://rubygems.org/gems/philiprehberger-dot_access)
[![License](https://img.shields.io/github/license/philiprehberger/rb-dot-access)](LICENSE)

Dot-notation accessor for nested hashes with nil-safe traversal

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-dot_access"
```

Or install directly:

```bash
gem install philiprehberger-dot_access
```

## Usage

```ruby
require "philiprehberger/dot_access"

config = Philiprehberger::DotAccess.wrap({ database: { host: 'localhost', port: 5432 } })
config.database.host  # => "localhost"
config.database.port  # => 5432
```

### Nil-Safe Traversal

```ruby
config = Philiprehberger::DotAccess.wrap({ name: 'app' })
config.missing.nested.value  # => nil (never raises)
```

### Path-Based Access

```ruby
config = Philiprehberger::DotAccess.wrap({ a: { b: { c: 'deep' } } })
config.get('a.b.c')                        # => "deep"
config.get('a.b.missing', default: 'nope') # => "nope"
```

### Immutable Updates

```ruby
config  = Philiprehberger::DotAccess.wrap({ database: { port: 3306 } })
updated = config.set('database.port', 5432)

updated.database.port  # => 5432
config.database.port   # => 3306 (unchanged)
```

### YAML Loading

```ruby
config = Philiprehberger::DotAccess.from_yaml('config.yml')
config.database.host  # => value from YAML file
```

### JSON Loading

```ruby
config = Philiprehberger::DotAccess.from_json('{"database": {"host": "localhost"}}')
config.database.host  # => "localhost"
```

### Converting Back to Hash

```ruby
config = Philiprehberger::DotAccess.wrap({ a: { b: 1 } })
config.to_h  # => { a: { b: 1 } }
```

## API

### `Philiprehberger::DotAccess`

| Method | Description |
|--------|-------------|
| `.wrap(hash)` | Wrap a hash for dot-notation access |
| `.from_yaml(str_or_path)` | Parse YAML string or file and wrap the result |
| `.from_json(str)` | Parse JSON string and wrap the result |

### `Philiprehberger::DotAccess::Wrapper`

| Method | Description |
|--------|-------------|
| `#get(path, default: nil)` | Retrieve a value by dot-separated path |
| `#set(path, value)` | Return a new wrapper with the value set at the path |
| `#to_h` | Convert back to a plain hash |

### `Philiprehberger::DotAccess::NullAccess`

| Method | Description |
|--------|-------------|
| `#nil?` | Returns `true` |
| `#<any_method>` | Returns `nil` for any method call |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
