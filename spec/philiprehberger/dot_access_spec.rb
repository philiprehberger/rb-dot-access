# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tempfile'

RSpec.describe Philiprehberger::DotAccess do
  it 'has a version number' do
    expect(Philiprehberger::DotAccess::VERSION).not_to be_nil
  end

  describe '.wrap' do
    it 'raises an error for non-Hash input' do
      expect { described_class.wrap('not a hash') }.to raise_error(Philiprehberger::DotAccess::Error)
    end

    it 'wraps an empty hash' do
      wrapper = described_class.wrap({})
      expect(wrapper.to_h).to eq({})
    end
  end

  describe 'dot access' do
    let(:hash) { { database: { host: 'localhost', port: 5432 } } }
    let(:config) { described_class.wrap(hash) }

    it 'accesses single-level keys' do
      flat = described_class.wrap({ name: 'test' })
      expect(flat.name).to eq('test')
    end

    it 'accesses nested keys' do
      expect(config.database.host).to eq('localhost')
    end

    it 'accesses deeply nested keys' do
      deep = described_class.wrap({ a: { b: { c: { d: 'found' } } } })
      expect(deep.a.b.c.d).to eq('found')
    end

    it 'returns raw values for non-hash leaf nodes' do
      expect(config.database.port).to eq(5432)
    end

    it 'preserves array values' do
      wrapper = described_class.wrap({ tags: %w[ruby gem] })
      expect(wrapper.tags).to eq(%w[ruby gem])
    end
  end

  describe 'nil safety' do
    let(:config) { described_class.wrap({ name: 'test' }) }

    it 'returns nil for missing keys' do
      expect(config.nonexistent).to be_nil
    end

    it 'returns nil for chained missing keys' do
      expect(config.nonexistent.nested.value).to be_nil
    end

    it 'returns a NullAccess for missing keys' do
      expect(config.missing).to be_a(Philiprehberger::DotAccess::NullAccess)
    end

    it 'NullAccess responds to any method' do
      null = config.missing
      expect(null).to respond_to(:anything)
      expect(null).to respond_to(:foo)
    end
  end

  describe '#get' do
    let(:hash) { { a: { b: { c: 'deep' } } } }
    let(:config) { described_class.wrap(hash) }

    it 'retrieves values by dot-path' do
      expect(config.get('a.b.c')).to eq('deep')
    end

    it 'retrieves single-level values' do
      flat = described_class.wrap({ key: 'value' })
      expect(flat.get('key')).to eq('value')
    end

    it 'returns nil for missing paths' do
      expect(config.get('a.b.missing')).to be_nil
    end

    it 'returns the default for missing paths' do
      expect(config.get('a.b.missing', default: 'fallback')).to eq('fallback')
    end

    it 'returns the default for completely missing paths' do
      expect(config.get('x.y.z', default: 42)).to eq(42)
    end

    it 'does not return the default when the value exists' do
      expect(config.get('a.b.c', default: 'nope')).to eq('deep')
    end
  end

  describe '#set' do
    let(:hash) { { a: { b: 1 } } }
    let(:config) { described_class.wrap(hash) }

    it 'returns a new instance' do
      updated = config.set('a.b', 2)
      expect(updated).to be_a(Philiprehberger::DotAccess::Wrapper)
      expect(updated).not_to eq(config)
    end

    it 'does not modify the original' do
      config.set('a.b', 99)
      expect(config.get('a.b')).to eq(1)
    end

    it 'sets a nested value' do
      updated = config.set('a.b', 2)
      expect(updated.get('a.b')).to eq(2)
    end

    it 'creates intermediate keys' do
      updated = config.set('x.y.z', 'new')
      expect(updated.get('x.y.z')).to eq('new')
    end

    it 'sets a top-level value' do
      updated = config.set('top', 'level')
      expect(updated.get('top')).to eq('level')
    end
  end

  describe '#to_h' do
    it 'returns the original hash structure' do
      hash = { name: 'test', nested: { key: 'value' } }
      config = described_class.wrap(hash)
      expect(config.to_h).to eq(hash)
    end

    it 'returns an empty hash for empty wrapper' do
      config = described_class.wrap({})
      expect(config.to_h).to eq({})
    end
  end

  describe '.from_yaml' do
    it 'parses a YAML string' do
      yaml = "database:\n  host: localhost\n  port: 5432\n"
      config = described_class.from_yaml(yaml)
      expect(config.database.host).to eq('localhost')
      expect(config.database.port).to eq(5432)
    end

    it 'parses a YAML file' do
      file = Tempfile.new(['config', '.yml'])
      file.write("app:\n  name: test\n")
      file.close

      config = described_class.from_yaml(file.path)
      expect(config.app.name).to eq('test')
    ensure
      file&.unlink
    end
  end

  describe '.from_json' do
    it 'parses a JSON string' do
      json = '{"database": {"host": "localhost", "port": 5432}}'
      config = described_class.from_json(json)
      expect(config.database.host).to eq('localhost')
      expect(config.database.port).to eq(5432)
    end

    it 'handles nested JSON' do
      json = '{"a": {"b": {"c": "deep"}}}'
      config = described_class.from_json(json)
      expect(config.get('a.b.c')).to eq('deep')
    end
  end

  describe '#exists?' do
    let(:hash) { { a: { b: { c: 'deep' } }, x: nil } }
    let(:config) { described_class.wrap(hash) }

    it 'returns true for existing top-level keys' do
      expect(config.exists?('a')).to be(true)
    end

    it 'returns true for nested paths' do
      expect(config.exists?('a.b.c')).to be(true)
    end

    it 'returns true for paths with nil values' do
      expect(config.exists?('x')).to be(true)
    end

    it 'returns false for non-existent paths' do
      expect(config.exists?('z')).to be(false)
    end

    it 'returns false for non-existent nested paths' do
      expect(config.exists?('a.b.missing')).to be(false)
    end

    it 'returns false for paths beyond leaf nodes' do
      expect(config.exists?('a.b.c.d')).to be(false)
    end

    it 'returns false on empty hash' do
      empty = described_class.wrap({})
      expect(empty.exists?('anything')).to be(false)
    end
  end

  describe '#keys' do
    it 'returns top-level keys for flat hash' do
      config = described_class.wrap({ a: 1, b: 2 })
      expect(config.keys).to contain_exactly('a', 'b')
    end

    it 'returns dot-paths for nested hash' do
      config = described_class.wrap({ a: { b: 1 }, c: 2 })
      expect(config.keys).to contain_exactly('a.b', 'c')
    end

    it 'returns deeply nested dot-paths' do
      config = described_class.wrap({ a: { b: { c: { d: 1 } } } })
      expect(config.keys).to eq(['a.b.c.d'])
    end

    it 'limits depth when specified' do
      config = described_class.wrap({ a: { b: { c: 1 } }, d: 2 })
      expect(config.keys(depth: 1)).to contain_exactly('a', 'd')
    end

    it 'limits depth at 2' do
      config = described_class.wrap({ a: { b: { c: 1 } }, d: 2 })
      expect(config.keys(depth: 2)).to contain_exactly('a.b', 'd')
    end

    it 'returns empty array for empty hash' do
      config = described_class.wrap({})
      expect(config.keys).to eq([])
    end
  end

  describe '#delete' do
    let(:hash) { { a: { b: 1, c: 2 }, d: 3 } }
    let(:config) { described_class.wrap(hash) }

    it 'removes a top-level key' do
      result = config.delete('d')
      expect(result.to_h).to eq({ a: { b: 1, c: 2 } })
    end

    it 'removes a nested key' do
      result = config.delete('a.b')
      expect(result.to_h).to eq({ a: { c: 2 }, d: 3 })
    end

    it 'returns a new wrapper (immutable)' do
      result = config.delete('d')
      expect(result).not_to eq(config)
      expect(config.get('d')).to eq(3)
    end

    it 'handles deleting a non-existent path gracefully' do
      result = config.delete('z.y.x')
      expect(result.to_h).to eq(hash)
    end

    it 'handles empty hash' do
      empty = described_class.wrap({})
      result = empty.delete('anything')
      expect(result.to_h).to eq({})
    end
  end

  describe '#flatten' do
    it 'flattens a nested hash' do
      config = described_class.wrap({ a: { b: 1 }, c: 2 })
      expect(config.flatten).to eq({ 'a.b' => 1, 'c' => 2 })
    end

    it 'flattens deeply nested hash' do
      config = described_class.wrap({ a: { b: { c: { d: 'deep' } } } })
      expect(config.flatten).to eq({ 'a.b.c.d' => 'deep' })
    end

    it 'handles flat hash' do
      config = described_class.wrap({ x: 1, y: 2 })
      expect(config.flatten).to eq({ 'x' => 1, 'y' => 2 })
    end

    it 'handles empty hash' do
      config = described_class.wrap({})
      expect(config.flatten).to eq({})
    end

    it 'preserves array values' do
      config = described_class.wrap({ a: { b: [1, 2] } })
      expect(config.flatten).to eq({ 'a.b' => [1, 2] })
    end
  end

  describe '#merge' do
    it 'merges with a Hash' do
      config = described_class.wrap({ a: 1 })
      result = config.merge({ b: 2 })
      expect(result.to_h).to eq({ a: 1, b: 2 })
    end

    it 'merges with another Wrapper' do
      config = described_class.wrap({ a: 1 })
      other = described_class.wrap({ b: 2 })
      result = config.merge(other)
      expect(result.to_h).to eq({ a: 1, b: 2 })
    end

    it 'other values take precedence for overlapping keys' do
      config = described_class.wrap({ a: 1, b: 2 })
      result = config.merge({ a: 10 })
      expect(result.get('a')).to eq(10)
      expect(result.get('b')).to eq(2)
    end

    it 'deep merges nested hashes' do
      config = described_class.wrap({ a: { b: 1, c: 2 } })
      result = config.merge({ a: { c: 3, d: 4 } })
      expect(result.to_h).to eq({ a: { b: 1, c: 3, d: 4 } })
    end

    it 'returns a new Wrapper' do
      config = described_class.wrap({ a: 1 })
      result = config.merge({ b: 2 })
      expect(result).to be_a(Philiprehberger::DotAccess::Wrapper)
      expect(config.to_h).to eq({ a: 1 })
    end

    it 'handles merging with empty hash' do
      config = described_class.wrap({ a: 1 })
      result = config.merge({})
      expect(result.to_h).to eq({ a: 1 })
    end

    it 'handles merging empty wrapper with hash' do
      config = described_class.wrap({})
      result = config.merge({ a: 1 })
      expect(result.to_h).to eq({ a: 1 })
    end

    it 'normalizes string keys from Hash argument' do
      config = described_class.wrap({ a: 1 })
      result = config.merge({ 'b' => 2 })
      expect(result.get('b')).to eq(2)
    end
  end

  describe '#compact' do
    it 'removes nil values from a flat hash' do
      config = described_class.wrap({ a: 1, b: nil, c: 3 })
      expect(config.compact.to_h).to eq({ a: 1, c: 3 })
    end

    it 'removes nil-valued keys from nested hashes' do
      config = described_class.wrap({ a: { b: 1, c: nil }, d: nil, e: { f: 2 } })
      expect(config.compact.to_h).to eq({ a: { b: 1 }, e: { f: 2 } })
    end

    it 'removes nil elements from arrays' do
      config = described_class.wrap({ items: [1, nil, 2, nil, 3] })
      expect(config.compact.to_h).to eq({ items: [1, 2, 3] })
    end

    it 'handles deeply nested mix of hashes and arrays' do
      config = described_class.wrap(
        { a: { b: [1, nil, { c: nil, d: 2 }], e: nil }, f: nil, g: [nil, nil] }
      )
      expect(config.compact.to_h).to eq({ a: { b: [1, { d: 2 }] }, g: [] })
    end

    it 'returns structurally equal wrapper when there are no nils' do
      hash = { a: 1, b: { c: 2, d: [3, 4] } }
      config = described_class.wrap(hash)
      expect(config.compact.to_h).to eq(hash)
    end

    it 'preserves an empty hash' do
      config = described_class.wrap({})
      expect(config.compact.to_h).to eq({})
    end

    it 'preserves empty hashes produced by compaction' do
      config = described_class.wrap({ a: { b: nil }, c: 1 })
      expect(config.compact.to_h).to eq({ a: {}, c: 1 })
    end

    it 'does not mutate the original' do
      hash = { a: 1, b: nil, c: { d: nil, e: 2 } }
      config = described_class.wrap(hash)
      config.compact
      expect(config.to_h).to eq({ a: 1, b: nil, c: { d: nil, e: 2 } })
    end

    it 'returns a new Wrapper instance' do
      config = described_class.wrap({ a: 1, b: nil })
      expect(config.compact).to be_a(Philiprehberger::DotAccess::Wrapper)
    end
  end

  describe '#fetch!' do
    let(:config) { described_class.wrap({ a: { b: { c: 'deep' } }, x: nil }) }

    it 'returns the value at the path' do
      expect(config.fetch!('a.b.c')).to eq('deep')
    end

    it 'returns nil values that exist' do
      expect(config.fetch!('x')).to be_nil
    end

    it 'raises KeyError for missing paths' do
      expect { config.fetch!('a.b.missing') }.to raise_error(KeyError, /a\.b\.missing/)
    end

    it 'raises KeyError for completely missing paths' do
      expect { config.fetch!('z.y') }.to raise_error(KeyError)
    end
  end

  describe '#slice' do
    let(:config) { described_class.wrap({ a: { b: 1, c: 2 }, d: 3, e: 4 }) }

    it 'returns a new Wrapper with only the given paths' do
      result = config.slice('a.b', 'd')
      expect(result.to_h).to eq({ a: { b: 1 }, d: 3 })
    end

    it 'returns an empty Wrapper when no paths match' do
      expect(config.slice('z').to_h).to eq({})
    end

    it 'ignores missing paths' do
      result = config.slice('a.b', 'missing')
      expect(result.to_h).to eq({ a: { b: 1 } })
    end

    it 'does not mutate the original' do
      config.slice('a.b')
      expect(config.to_h).to eq({ a: { b: 1, c: 2 }, d: 3, e: 4 })
    end
  end

  describe '#values_at' do
    let(:config) { described_class.wrap({ a: { b: 1 }, c: 2 }) }

    it 'returns values for the given paths in order' do
      expect(config.values_at('a.b', 'c')).to eq([1, 2])
    end

    it 'returns nil for missing paths' do
      expect(config.values_at('a.b', 'missing')).to eq([1, nil])
    end

    it 'returns an empty array when given no paths' do
      expect(config.values_at).to eq([])
    end
  end

  describe '#each / #each_pair' do
    let(:config) { described_class.wrap({ a: 1, b: { c: 2 } }) }

    it 'yields top-level key-value pairs' do
      pairs = config.map { |key, value| [key, value.is_a?(Philiprehberger::DotAccess::Wrapper) ? value.to_h : value] }
      expect(pairs).to contain_exactly([:a, 1], [:b, { c: 2 }])
    end

    it 'returns an enumerator without a block' do
      expect(config.each).to be_a(Enumerator)
    end

    it 'wraps nested hashes in the yielded values' do
      config.each do |key, value|
        expect(value).to be_a(Philiprehberger::DotAccess::Wrapper) if key == :b
      end
    end

    it 'is aliased as each_pair' do
      pairs = config.each_pair.to_a.map { |k, v| [k, v.is_a?(Philiprehberger::DotAccess::Wrapper) ? v.to_h : v] }
      expect(pairs).to contain_exactly([:a, 1], [:b, { c: 2 }])
    end
  end

  describe 'Enumerable' do
    let(:config) { described_class.wrap({ a: 1, b: 2, c: 3 }) }

    it 'supports map' do
      values = config.map { |_key, value| value * 2 }
      expect(values).to contain_exactly(2, 4, 6)
    end

    it 'supports select' do
      result = config.select { |_key, value| value > 1 }
      expect(result.map { |k, _v| k }).to contain_exactly(:b, :c)
    end

    it 'supports any?' do
      expect(config.any? { |_key, value| value == 2 }).to be(true)
      expect(config.any? { |_key, value| value == 99 }).to be(false)
    end

    it 'supports none?' do
      expect(config.none? { |_key, value| value == 99 }).to be(true)
    end
  end

  describe '#empty?' do
    it 'returns true for empty wrapper' do
      expect(described_class.wrap({}).empty?).to be(true)
    end

    it 'returns false for non-empty wrapper' do
      expect(described_class.wrap({ a: 1 }).empty?).to be(false)
    end
  end

  describe '#size / #count' do
    it 'returns the number of top-level keys' do
      config = described_class.wrap({ a: 1, b: { c: 2 }, d: 3 })
      expect(config.size).to eq(3)
    end

    it 'returns 0 for empty wrapper' do
      expect(described_class.wrap({}).size).to eq(0)
    end

    it 'is aliased as count' do
      config = described_class.wrap({ a: 1, b: 2 })
      expect(config.count).to eq(2)
    end
  end

  describe '#to_json' do
    it 'serializes to JSON string' do
      config = described_class.wrap({ name: 'app', port: 3000 })
      parsed = JSON.parse(config.to_json)
      expect(parsed).to eq({ 'name' => 'app', 'port' => 3000 })
    end

    it 'serializes nested structures' do
      config = described_class.wrap({ a: { b: 1 } })
      parsed = JSON.parse(config.to_json)
      expect(parsed).to eq({ 'a' => { 'b' => 1 } })
    end
  end

  describe '#to_yaml' do
    it 'serializes to YAML string' do
      config = described_class.wrap({ name: 'app', port: 3000 })
      parsed = YAML.safe_load(config.to_yaml, permitted_classes: [Symbol])
      expect(parsed).to eq({ name: 'app', port: 3000 })
    end

    it 'serializes nested structures' do
      config = described_class.wrap({ a: { b: 1 } })
      parsed = YAML.safe_load(config.to_yaml, permitted_classes: [Symbol])
      expect(parsed).to eq({ a: { b: 1 } })
    end
  end

  describe 'edge cases' do
    it 'handles an empty hash' do
      config = described_class.wrap({})
      expect(config.anything).to be_nil
    end

    it 'normalizes string keys to symbols' do
      config = described_class.wrap({ 'name' => 'test' })
      expect(config.name).to eq('test')
    end

    it 'handles mixed string and symbol keys' do
      config = described_class.wrap({ 'a' => 1, b: 2 })
      expect(config.a).to eq(1)
      expect(config.b).to eq(2)
    end

    it 'preserves array values in nested hashes' do
      config = described_class.wrap({ items: [1, 2, 3] })
      expect(config.items).to eq([1, 2, 3])
    end

    it 'handles boolean values' do
      config = described_class.wrap({ enabled: true, disabled: false })
      expect(config.enabled).to be(true)
      expect(config.disabled).to be(false)
    end

    it 'compares equal wrappers' do
      a = described_class.wrap({ key: 'value' })
      b = described_class.wrap({ key: 'value' })
      expect(a).to eq(b)
    end

    it 'provides meaningful inspect output' do
      config = described_class.wrap({ a: 1 })
      expect(config.inspect).to include('DotAccess::Wrapper')
    end
  end
end
