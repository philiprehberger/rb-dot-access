# philiprehberger-dot_access

[![Tests](https://github.com/philiprehberger/rb-dot-access/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-dot-access/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-dot_access.svg)](https://rubygems.org/gems/philiprehberger-dot_access)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-dot-access)](https://github.com/philiprehberger/rb-dot-access/commits/main)

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

### Path Existence Check

```ruby
config = Philiprehberger::DotAccess.wrap({ a: { b: 1 }, x: nil })
config.exists?('a.b')     # => true
config.exists?('x')       # => true  (nil values still exist)
config.exists?('missing') # => false
```

### Key Listing

```ruby
config = Philiprehberger::DotAccess.wrap({ a: { b: { c: 1 } }, d: 2 })
config.keys              # => ["a.b.c", "d"]
config.keys(depth: 1)    # => ["a", "d"]
```

### Immutable Deletion

```ruby
config  = Philiprehberger::DotAccess.wrap({ a: { b: 1, c: 2 }, d: 3 })
updated = config.delete('a.b')

updated.to_h  # => { a: { c: 2 }, d: 3 }
config.to_h   # => { a: { b: 1, c: 2 }, d: 3 } (unchanged)
```

### Flatten

```ruby
config = Philiprehberger::DotAccess.wrap({ a: { b: 1 }, c: 2 })
config.flatten  # => { "a.b" => 1, "c" => 2 }
```

### Deep Merge

```ruby
config = Philiprehberger::DotAccess.wrap({ a: { b: 1, c: 2 } })
merged = config.merge({ a: { c: 3, d: 4 } })

merged.to_h  # => { a: { b: 1, c: 3, d: 4 } }
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
| `#exists?(path)` | Check if a dot-separated path exists (even if value is nil) |
| `#keys(depth: nil)` | List all dot-path keys, optionally limited by depth |
| `#delete(path)` | Return a new wrapper without the specified path |
| `#flatten` | Convert to a flat hash with dot-path string keys |
| `#merge(other)` | Deep merge with another Wrapper or Hash, returning a new Wrapper |
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

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-dot-access)

🐛 [Report issues](https://github.com/philiprehberger/rb-dot-access/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-dot-access/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
