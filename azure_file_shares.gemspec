require_relative "lib/azure_file_shares/version"

Gem::Specification.new do |spec|
  spec.name        = "azure_file_shares"
  spec.version     = AzureFileShares::VERSION
  spec.authors     = [ "Dmitry Trager" ]
  spec.email       = [ "dmitry.trager@revealbot.com" ]
  spec.summary     = "Ruby client for Microsoft Azure File Shares API"
  spec.description = "A Ruby gem for interacting with the Microsoft Azure File Shares API"
  spec.homepage    = "https://github.com/dmitrytrager/azure_file_shares"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "documentation_uri" => "#{spec.homepage}/blob/main/README.md",
  }

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md"]
  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]

  # Dependencies
  spec.add_dependency "faraday", "~> 2.7"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "jwt", "~> 2.7"
  spec.add_dependency "nokogiri", "~> 1.15"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "vcr", "~> 6.1"
end
