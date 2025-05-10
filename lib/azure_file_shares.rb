require "faraday"
require "faraday/retry"
require "json"
require "uri"
require "nokogiri"

require_relative "azure_file_shares/version"
require_relative "azure_file_shares/configuration"
require_relative "azure_file_shares/client"

# Auth
require_relative "azure_file_shares/auth/token_provider"

# Resources
require_relative "azure_file_shares/resources/file_share"
require_relative "azure_file_shares/resources/file_share_snapshot"

# Operations
require_relative "azure_file_shares/operations/base_operation"
require_relative "azure_file_shares/operations/file_shares_operations"
require_relative "azure_file_shares/operations/snapshots_operations"
require_relative "azure_file_shares/operations/file_operations"

# Errors
require_relative "azure_file_shares/errors/api_error"
require_relative "azure_file_shares/errors/configuration_error"

# Main module for Azure File Shares API client
module AzureFileShares
  class << self
    attr_accessor :configuration

    # Configure the AzureFileShares client
    # @yield [config] Configuration object
    # @return [AzureFileShares::Configuration]
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    # Get or create a new client instance
    # @return [AzureFileShares::Client]
    def client
      @client ||= Client.new(configuration)
    end

    # Reset the configuration
    # @return [AzureFileShares::Configuration]
    def reset
      self.configuration = Configuration.new
    end
  end
end
