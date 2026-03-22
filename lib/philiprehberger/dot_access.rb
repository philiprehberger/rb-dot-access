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
      # @return [nil]
      def method_missing(_name, *_args) # rubocop:disable Style/MissingRespondToMissing
        nil
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
          when Wrapper then current.dig(key.to_sym)
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

      def deep_set(hash, keys, value)
        key = keys.first.to_sym

        if keys.length == 1
          hash.merge(key => value)
        else
          child = hash.fetch(key, {})
          child = child.is_a?(Hash) ? child : {}
          hash.merge(key => deep_set(child, keys[1..], value))
        end
      end
    end
  end
end
