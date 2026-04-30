# frozen_string_literal: true

require 'json'
require 'yaml'
require_relative 'dot_access/version'

module Philiprehberger
  module DotAccess
    class Error < StandardError; end

    # Wrap a hash for dot-notation access
    #
    # @param hash [Hash] the hash to wrap
    # @return [Wrapper] a dot-accessible wrapper
    # @raise [Error] if argument is not a Hash
    def self.wrap(hash)
      raise Error, 'Expected a Hash' unless hash.is_a?(Hash)

      Wrapper.new(hash)
    end

    # Parse a YAML string or file path and wrap the result
    #
    # @param str_or_path [String] YAML string or path to a YAML file
    # @return [Wrapper] a dot-accessible wrapper
    # @raise [Error] if the parsed result is not a Hash
    def self.from_yaml(str_or_path)
      data = if File.exist?(str_or_path)
               YAML.safe_load_file(str_or_path, permitted_classes: [Symbol])
             else
               YAML.safe_load(str_or_path, permitted_classes: [Symbol])
             end

      wrap(normalize_keys(data))
    end

    # Build a Wrapper from a hash whose keys are dot-paths.
    #
    # Inverse of {Wrapper#flatten} — passing the result of `wrap(h).flatten`
    # back through `from_flat` reconstructs the original (symbol-keyed)
    # structure. Arrays are preserved as opaque values: `#flatten` does not
    # explode array elements into separate dot-paths, and `from_flat`
    # therefore cannot create new array slots from integer-only segments.
    #
    # @param hash [Hash] map of dot-paths to values
    # @return [Wrapper] a dot-accessible wrapper
    # @raise [Error] if `hash` is not a Hash
    def self.from_flat(hash)
      raise Error, 'Expected a Hash' unless hash.is_a?(Hash)

      hash.reduce(wrap({})) do |wrapper, (path, value)|
        wrapper.set(path, value)
      end
    end

    # Parse a JSON string and wrap the result
    #
    # @param str [String] JSON string
    # @return [Wrapper] a dot-accessible wrapper
    # @raise [Error] if the parsed result is not a Hash
    def self.from_json(str)
      data = JSON.parse(str)
      wrap(normalize_keys(data))
    end

    # Convert string keys to symbols recursively
    #
    # @param obj [Object] the object to normalize
    # @return [Object] the normalized object
    # @api private
    def self.normalize_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(key, value), memo|
          memo[key.is_a?(String) ? key.to_sym : key] = normalize_keys(value)
        end
      when Array
        obj.map { |item| normalize_keys(item) }
      else
        obj
      end
    end

    private_class_method :normalize_keys

    # Null object that responds to any method with nil
    class NullAccess
      # @return [NullAccess] returns self for chaining
      def method_missing(_name, *_args)
        self
      end

      # @return [true]
      def respond_to_missing?(_name, _include_private = false)
        true
      end

      # @return [true]
      def nil?
        true
      end

      # @return [String]
      def inspect
        '#<NullAccess>'
      end

      # @return [String]
      def to_s
        ''
      end
    end

    # Dot-notation wrapper for a hash
    class Wrapper
      include Enumerable

      # Regex matching strings that should be treated as array indices
      # (signed or unsigned integers).
      INDEX_SEGMENT = /\A-?\d+\z/

      # Wrap the given Hash and freeze the resulting instance.
      #
      # @param hash [Hash] the hash to wrap
      # @return [Wrapper] a frozen wrapper instance
      def initialize(hash)
        @data = hash.each_with_object({}) do |(key, value), memo|
          memo[key.is_a?(String) ? key.to_sym : key] = value
        end
        freeze
      end

      # Access a value by dot-path string.
      #
      # Path segments that look like integers (e.g. ``0``, ``-1``) are
      # interpreted as array indices when the value currently being
      # traversed is an {Array}. Otherwise they are treated as Hash keys.
      #
      # @param path [String, Symbol] dot-separated key path
      # @param default [Object] value returned if the path is not found
      # @return [Object] the value at the path, or ``default``
      def get(path, default: nil)
        keys = path.to_s.split('.')
        result = keys.reduce(@data) do |current, key|
          case current
          when Hash then current[key.to_sym]
          when Array
            index = array_index(key, current)
            return default if index.nil?

            current[index]
          when Wrapper then current[key.to_sym]
          else return default
          end
        end

        result.nil? ? default : result
      end

      # Set a value at a dot-path, returning a new Wrapper.
      #
      # Integer-looking path segments are applied as array indices when
      # the current node is an Array. Out-of-bounds indices raise
      # {ArgumentError}; negative indices follow Ruby conventions.
      #
      # @param path [String, Symbol] dot-separated key path
      # @param value [Object] the value to set
      # @return [Wrapper] a new wrapper with the updated value
      # @raise [ArgumentError] when an integer segment is out of bounds
      #   for the current Array node
      def set(path, value)
        keys = path.to_s.split('.')
        new_data = deep_set(to_h, keys, value)
        Wrapper.new(new_data)
      end

      # Check whether a dot-separated path exists in the wrapped structure.
      #
      # @param path [String, Symbol] dot-separated key path
      # @return [Boolean] ``true`` if the path exists (even when the value
      #   at the path is ``nil``)
      def exists?(path)
        keys = path.to_s.split('.')
        current = @data
        keys.each do |key|
          case current
          when Hash
            return false unless current.key?(key.to_sym)

            current = current[key.to_sym]
          when Array
            index = array_index(key, current)
            return false if index.nil?

            current = current[index]
          when Wrapper
            return false unless current.key?(key.to_sym)

            current = current[key.to_sym]
          else
            return false
          end
        end
        true
      end

      # List every dot-path in the wrapped structure.
      #
      # @param depth [Integer, nil] maximum traversal depth (``nil`` for unlimited)
      # @return [Array<String>] dot-path strings
      def keys(depth: nil)
        collect_keys(@data, '', depth, 1)
      end

      # Fetch a value at a dot-path, raising if missing.
      #
      # @param path [String, Symbol] dot-separated key path
      # @return [Object] the value at the path
      # @raise [KeyError] if the path does not exist
      def fetch!(path)
        raise KeyError, "path not found: #{path.inspect}" unless exists?(path)

        get(path)
      end

      # Return a new Wrapper containing only the specified dot-paths.
      #
      # @param paths [Array<String, Symbol>] dot-separated key paths to retain
      # @return [Wrapper] a new wrapper with only the given paths
      def slice(*paths)
        new_data = paths.reduce({}) do |acc, path|
          next acc unless exists?(path)

          deep_set(acc, path.to_s.split('.'), get(path))
        end
        Wrapper.new(new_data)
      end

      # Return values at the given dot-paths as an array.
      #
      # @param paths [Array<String, Symbol>] dot-separated key paths
      # @return [Array<Object>] values in the order of the given paths
      def values_at(*paths)
        paths.map { |path| get(path) }
      end

      # Remove a key at a dot-path, returning a new Wrapper.
      #
      # Integer-looking segments delete the matching array element when
      # the current node is an Array.
      #
      # @param path [String, Symbol] dot-separated key path
      # @return [Wrapper] a new wrapper without the specified path
      def delete(path)
        keys = path.to_s.split('.')
        new_data = deep_delete(to_h, keys)
        Wrapper.new(new_data)
      end

      # Flatten the nested structure into a hash whose keys are dot-paths.
      #
      # @return [Hash] flat hash where keys are dot-path strings
      def flatten
        flatten_hash(@data, '')
      end

      # Return a new Wrapper with all ``nil`` values removed at every depth.
      #
      # @return [Wrapper] a new wrapper with nils removed from hashes and arrays
      def compact
        Philiprehberger::DotAccess.wrap(deep_compact(to_h))
      end

      # Deep merge with another Wrapper or Hash.
      #
      # @param other [Wrapper, Hash] the other structure to merge
      # @return [Wrapper] a new wrapper with merged values
      def merge(other)
        other_hash = other.is_a?(Wrapper) ? other.to_h : symbolize_keys(other)
        merged = deep_merge(to_h, other_hash)
        Wrapper.new(merged)
      end

      # Batch-set multiple dot-paths, returning a new Wrapper.
      #
      # Applies every entry in ``paths_hash`` in iteration order, following
      # the same semantics as {#set}. The receiver is not mutated.
      #
      # @param paths_hash [Hash{String, Symbol => Object}] map of dot-paths
      #   to values
      # @return [Wrapper] a new frozen wrapper with every path applied
      # @raise [ArgumentError] when an integer segment is out of bounds
      #   for an Array node (propagated from {#set})
      def update(paths_hash)
        new_data = paths_hash.reduce(to_h) do |acc, (path, value)|
          deep_set(acc, path.to_s.split('.'), value)
        end
        Wrapper.new(new_data)
      end

      # Iterate over top-level key-value pairs.
      #
      # Nested Hash values are yielded as wrapped {Wrapper} instances so
      # block callers can chain dot-notation.
      #
      # @yield [Symbol, Object] each key and its (possibly wrapped) value
      # @return [Enumerator] if no block is given
      def each(&)
        return enum_for(:each) unless block_given?

        @data.each do |key, value|
          yield key, wrap_value(value)
        end
      end

      alias each_pair each

      # @return [Boolean] ``true`` if the wrapped hash has no keys
      def empty?
        @data.empty?
      end

      # @return [Integer] the number of top-level keys
      def size
        @data.size
      end

      alias count size

      # Serialize the wrapped hash to a JSON string.
      #
      # @param args [Array<Object>] passed through to ``Hash#to_json``
      # @return [String] JSON representation
      def to_json(*args)
        to_h.to_json(*args)
      end

      # Serialize the wrapped hash to a YAML string.
      #
      # @param args [Array<Object>] passed through to ``Hash#to_yaml``
      # @return [String] YAML representation
      def to_yaml(*args)
        to_h.to_yaml(*args)
      end

      # Check if a key exists in the underlying data.
      #
      # @param key [Symbol] the key to check
      # @return [Boolean]
      # @api private
      def key?(key)
        @data.key?(key)
      end

      # Return the underlying hash with symbol keys.
      #
      # @return [Hash] the original hash structure
      def to_h
        @data.each_with_object({}) do |(key, value), memo|
          memo[key] = value.is_a?(Wrapper) ? value.to_h : value
        end
      end

      # Dig into nested keys.
      #
      # @param key [Symbol] the key to look up
      # @return [Object] the (possibly wrapped) value
      # @api private
      def dig(key)
        value = @data[key]
        wrap_value(value)
      end

      # @return [String]
      def inspect
        "#<DotAccess::Wrapper #{to_h.inspect}>"
      end

      # @return [Boolean]
      def ==(other)
        return to_h == other.to_h if other.is_a?(Wrapper)

        false
      end

      private

      def method_missing(name, *args)
        if @data.key?(name)
          wrap_value(@data[name])
        elsif name.to_s.end_with?('=') || !args.empty?
          super
        else
          NullAccess.new
        end
      end

      def respond_to_missing?(name, include_private = false)
        @data.key?(name) || super
      end

      def wrap_value(value)
        case value
        when Hash then Wrapper.new(value)
        when NilClass then NullAccess.new
        else value
        end
      end

      # Resolve an array index segment against a concrete Array value.
      # Returns nil when the segment does not look like an integer or is
      # out of bounds (read-time semantics; see #deep_set for writes).
      def array_index(segment, array)
        return nil unless segment.to_s.match?(INDEX_SEGMENT)

        raw = segment.to_i
        normalized = raw.negative? ? raw + array.length : raw
        return nil if normalized.negative? || normalized >= array.length

        normalized
      end

      def collect_keys(hash, prefix, max_depth, current_depth)
        result = []
        hash.each do |key, value|
          full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
          if value.is_a?(Hash) && (max_depth.nil? || current_depth < max_depth)
            result.concat(collect_keys(value, full_key, max_depth, current_depth + 1))
          else
            result << full_key
          end
        end
        result
      end

      def deep_delete(hash_or_array, keys)
        case hash_or_array
        when Hash
          deep_delete_hash(hash_or_array, keys)
        when Array
          deep_delete_array(hash_or_array, keys)
        else
          hash_or_array
        end
      end

      def deep_delete_hash(hash, keys)
        key = keys.first.to_sym
        return hash.reject { |k, _| k == key } if keys.length == 1
        return hash unless hash.key?(key)

        child = hash[key]
        return hash unless child.is_a?(Hash) || child.is_a?(Array)

        hash.merge(key => deep_delete(child, keys[1..]))
      end

      def deep_delete_array(array, keys)
        segment = keys.first
        return array unless segment.match?(INDEX_SEGMENT)

        index = array_index(segment, array)
        return array if index.nil?

        if keys.length == 1
          array.each_with_index.reject { |_, i| i == index }.map(&:first)
        else
          child = array[index]
          return array unless child.is_a?(Hash) || child.is_a?(Array)

          new_array = array.dup
          new_array[index] = deep_delete(child, keys[1..])
          new_array
        end
      end

      def flatten_hash(hash, prefix)
        result = {}
        hash.each do |key, value|
          full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
          if value.is_a?(Hash)
            result.merge!(flatten_hash(value, full_key))
          else
            result[full_key] = value
          end
        end
        result
      end

      def deep_merge(base, other)
        base.merge(other) do |_key, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge(old_val, new_val)
          else
            new_val
          end
        end
      end

      def symbolize_keys(hash)
        hash.each_with_object({}) do |(key, value), memo|
          sym_key = key.is_a?(String) ? key.to_sym : key
          memo[sym_key] = value.is_a?(Hash) ? symbolize_keys(value) : value
        end
      end

      def deep_compact(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(key, value), memo|
            compacted = deep_compact(value)
            memo[key] = compacted unless compacted.nil?
          end
        when Array
          obj.map { |item| deep_compact(item) }.compact
        else
          obj
        end
      end

      def deep_set(target, keys, value)
        case target
        when Array then deep_set_array(target, keys, value)
        else deep_set_hash(target.is_a?(Hash) ? target : {}, keys, value)
        end
      end

      def deep_set_hash(hash, keys, value)
        key = keys.first.to_sym

        if keys.length == 1
          hash.merge(key => value)
        else
          child = hash.fetch(key, default_for_segment(keys[1]))
          child = default_for_segment(keys[1]) unless compatible_child?(child, keys[1])
          hash.merge(key => deep_set(child, keys[1..], value))
        end
      end

      def deep_set_array(array, keys, value)
        segment = keys.first
        unless segment.match?(INDEX_SEGMENT)
          raise ArgumentError,
                "expected integer index for array segment, got #{segment.inspect}"
        end

        index = resolve_write_index(segment, array)
        new_array = array.dup

        if keys.length == 1
          new_array[index] = value
        else
          child = new_array[index]
          child = default_for_segment(keys[1]) unless compatible_child?(child, keys[1])
          new_array[index] = deep_set(child, keys[1..], value)
        end

        new_array
      end

      # Return true when ``child`` is a suitable container for the given
      # next segment (Array for index-like segments, Hash otherwise).
      def compatible_child?(child, next_segment)
        if next_segment.to_s.match?(INDEX_SEGMENT)
          child.is_a?(Array)
        else
          child.is_a?(Hash)
        end
      end

      # Resolve a write-time array index, raising on out-of-bounds access.
      # Negative indices follow Ruby's conventions (``-1`` = last element).
      def resolve_write_index(segment, array)
        raw = segment.to_i
        normalized = raw.negative? ? raw + array.length : raw
        if normalized.negative? || normalized >= array.length
          raise ArgumentError,
                "index #{raw} out of bounds for array of size #{array.length}"
        end

        normalized
      end

      # Choose an appropriate empty container for a newly-created
      # intermediate node based on the next path segment: an Array when
      # the next segment looks like an index, otherwise a Hash.
      def default_for_segment(segment)
        segment.to_s.match?(INDEX_SEGMENT) ? [] : {}
      end
    end
  end
end
