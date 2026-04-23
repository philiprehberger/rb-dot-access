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

### Array Element Access

Integer path segments are treated as array indices when the current
value is an `Array`. Negative indices count from the end, following
Ruby conventions.

```ruby
config = Philiprehberger::DotAccess.wrap(
  { items: [{ name: 'a' }, { name: 'b' }] }
)

config.get('items.0.name')   # => "a"
config.get('items.-1.name')  # => "b"
config.exists?('items.1')    # => true
config.get('items.99.name')  # => nil

updated = config.set('items.0.name', 'A')
updated.get('items.0.name')  # => "A"

config.delete('items.0').get('items').map { |i| i[:name] }
# => ["b"]
```

Out-of-bounds indices raise `ArgumentError` on `set`/`update` and
return `nil` on `get`.

### Batch Updates

```ruby
config  = Philiprehberger::DotAccess.wrap({ a: { b: 1, c: 2 }, d: 3 })
updated = config.update('a.b' => 10, 'd' => 30)

updated.get('a.b')  # => 10
updated.get('a.c')  # => 2 (unchanged)
updated.get('d')    # => 30
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

### Strict Fetch

```ruby
config = Philiprehberger::DotAccess.wrap({ database: { host: 'localhost' } })
config.fetch!('database.host')  # => "localhost"
config.fetch!('database.port')  # raises KeyError
```

### Slice and Values At

```ruby
config = Philiprehberger::DotAccess.wrap({ a: { b: 1, c: 2 }, d: 3 })
config.slice('a.b', 'd').to_h   # => { a: { b: 1 }, d: 3 }
config.values_at('a.b', 'd')    # => [1, 3]
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

### Compact

```ruby
config = Philiprehberger::DotAccess.wrap({ a: 1, b: nil, c: { d: nil, e: 2 }, f: [1, nil, 2] })
config.compact.to_h  # => { a: 1, c: { e: 2 }, f: [1, 2] }
```

### Deep Merge

```ruby
config = Philiprehberger::DotAccess.wrap({ a: { b: 1, c: 2 } })
merged = config.merge({ a: { c: 3, d: 4 } })

merged.to_h  # => { a: { b: 1, c: 3, d: 4 } }
```

### Iteration

```ruby
config = Philiprehberger::DotAccess.wrap({ a: 1, b: { c: 2 } })
config.each { |key, value| puts "#{key}: #{value}" }
config.map { |_key, value| value }   # Enumerable methods included
config.select { |key, _value| key == :a }
```

### Size and Emptiness

```ruby
config = Philiprehberger::DotAccess.wrap({ a: 1, b: 2 })
config.size    # => 2
config.empty?  # => false
```

### Serialization

```ruby
config = Philiprehberger::DotAccess.wrap({ database: { host: "localhost" } })
config.to_json  # => '{"database":{"host":"localhost"}}'
config.to_yaml  # => "---\ndatabase:\n  host: localhost\n"
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
| `#get(path, default: nil)` | Retrieve a value by dot-separated path (supports array indices) |
| `#fetch!(path)` | Retrieve a value or raise `KeyError` if the path is missing |
| `#set(path, value)` | Return a new wrapper with the value set at the path (supports array indices) |
| `#update(paths_hash)` | Batch-set multiple dot-paths, returning a new wrapper |
| `#slice(*paths)` | Return a new wrapper containing only the given paths |
| `#values_at(*paths)` | Return an array of values at the given paths |
| `#exists?(path)` | Check if a dot-separated path exists (even if value is nil) |
| `#keys(depth: nil)` | List all dot-path keys, optionally limited by depth |
| `#delete(path)` | Return a new wrapper without the specified path (supports array indices) |
| `#flatten` | Convert to a flat hash with dot-path string keys |
| `#merge(other)` | Deep merge with another Wrapper or Hash, returning a new Wrapper |
| `#compact` | Return a new wrapper with all `nil` values removed at every depth |
| `#each` / `#each_pair` | Iterate over top-level key-value pairs |
| `#empty?` | Returns `true` if the wrapped hash has no keys |
| `#size` / `#count` | Returns the number of top-level keys |
| `#to_json` | Serialize back to a JSON string |
| `#to_yaml` | Serialize back to a YAML string |
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
