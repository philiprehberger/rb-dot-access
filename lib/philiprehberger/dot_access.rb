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
      # @param hash [Hash] the hash to wrap
      def initialize(hash)
        @data = hash.each_with_object({}) do |(key, value), memo|
          memo[key.is_a?(String) ? key.to_sym : key] = value
        end
        freeze
      end

      # Access a value by dot-path string
      #
      # @param path [String] dot-separated key path
      # @param default [Object] value to return if path is not found
      # @return [Object] the value at the path, or default
      def get(path, default: nil)
        keys = path.to_s.split('.')
        result = keys.reduce(@data) do |current, key|
          case current
          when Hash then current[key.to_sym]
          when Wrapper then current[key.to_sym]
          else return default
          end
        end

        result.nil? ? default : result
      end

      # Set a value at a dot-path, returning a new Wrapper
      #
      # @param path [String] dot-separated key path
      # @param value [Object] the value to set
      # @return [Wrapper] a new wrapper with the updated value
      def set(path, value)
        keys = path.to_s.split('.')
        new_data = deep_set(to_h, keys, value)
        Wrapper.new(new_data)
      end

      # Check if a dot-separated path exists in the wrapped hash
      #
      # @param path [String] dot-separated key path
      # @return [Boolean] true if the path exists (even if value is nil)
      def exists?(path)
        keys = path.to_s.split('.')
        current = @data
        keys.each do |key|
          case current
          when Hash
            return false unless current.key?(key.to_sym)

            current = current[key.to_sym]
          when Wrapper
            return false unless current.key?(key.to_sym)

            current = current[key.to_sym]
          else
            return false
          end
        end
        true
      end

      # Return all dot-path keys as strings
      #
      # @param depth [Integer, nil] maximum traversal depth (nil for unlimited)
      # @return [Array<String>] array of dot-path strings
      def keys(depth: nil)
        collect_keys(@data, '', depth, 1)
      end

      # Remove a key at a dot-path, returning a new Wrapper
      #
      # @param path [String] dot-separated key path
      # @return [Wrapper] a new wrapper without the specified path
      def delete(path)
        keys = path.to_s.split('.')
        new_data = deep_delete(to_h, keys)
        Wrapper.new(new_data)
      end

      # Flatten nested structure into a hash with dot-path keys
      #
      # @return [Hash] flat hash where keys are dot-path strings
      def flatten
        flatten_hash(@data, '')
      end

      # Deep merge with another Wrapper or Hash
      #
      # @param other [Wrapper, Hash] the other structure to merge
      # @return [Wrapper] a new wrapper with merged values
      def merge(other)
        other_hash = other.is_a?(Wrapper) ? other.to_h : symbolize_keys(other)
        merged = deep_merge(to_h, other_hash)
        Wrapper.new(merged)
      end

      # Check if a key exists in the underlying data
      #
      # @param key [Symbol] the key to check
      # @return [Boolean]
      # @api private
      def key?(key)
        @data.key?(key)
      end

      # Return the underlying hash
      #
      # @return [Hash] the original hash with symbol keys
      def to_h
        @data.each_with_object({}) do |(key, value), memo|
          memo[key] = value.is_a?(Wrapper) ? value.to_h : value
        end
      end

      # Dig into nested keys
      #
      # @param key [Symbol] the key to look up
      # @return [Object] the value
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

      def deep_delete(hash, keys)
        key = keys.first.to_sym
        return hash.reject { |k, _| k == key } if keys.length == 1
        return hash unless hash.key?(key) && hash[key].is_a?(Hash)

        child = deep_delete(hash[key], keys[1..])
        hash.merge(key => child)
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

      def deep_set(hash, keys, value)
        key = keys.first.to_sym

        if keys.length == 1
          hash.merge(key => value)
        else
          child = hash.fetch(key, {})
          child = {} unless child.is_a?(Hash)
          hash.merge(key => deep_set(child, keys[1..], value))
        end
      end
    end
  end
end
