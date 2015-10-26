# frozen_string_literal: true

require_relative 'lib/philiprehberger/dot_access/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-dot_access'
  spec.version       = Philiprehberger::DotAccess::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']

  spec.summary       = 'Dot-notation accessor for nested hashes with nil-safe traversal'
  spec.description   = 'Access deeply nested hash values using dot notation (config.database.host) ' \
                       'with nil-safe traversal that never raises on missing keys. Supports ' \
                       'path-based get/set, YAML/JSON loading, and immutable updates.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-dot-access'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files         = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
