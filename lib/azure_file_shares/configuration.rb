module AzureFileShares
  # Configuration options for the AzureFileShares client
  class Configuration
    # API endpoints
    DEFAULT_API_VERSION = "2024-01-01"
    DEFAULT_BASE_URL = "https://management.azure.com"

    # Configuration attributes
    attr_accessor :tenant_id,
                  :client_id,
                  :client_secret,
                  :subscription_id,
                  :resource_group_name,
                  :storage_account_name,
                  :storage_account_key,
                  # :sas_token,
                  :api_version,
                  :base_url,
                  :request_timeout,
                  :logger

    # Initialize a new Configuration object with default values
    def initialize
      @api_version = DEFAULT_API_VERSION
      @base_url = DEFAULT_BASE_URL
      @request_timeout = 60 # seconds
      @logger = nil
    end

    # Validates the configuration
    # @return [Boolean] true if valid
    # @raise [AzureFileShares::Errors::ConfigurationError] if configuration is invalid
    def validate!
      # For file operations with SAS token
      # if storage_account_name && sas_token
      #   return true
      # end

      # For file operations only
      if storage_account_name && storage_account_key
        return true
      end

      # For ARM operations (share management)
      required_fields = %i[tenant_id client_id client_secret subscription_id]
      missing_fields = required_fields.select { |field| send(field).nil? || send(field).to_s.strip.empty? }

      unless missing_fields.empty?
        missing = missing_fields.map(&:to_s).join(", ")
        raise AzureFileShares::Errors::ConfigurationError,
          "Missing required configuration: #{missing}. " +
          "Note: For file operations only, just storage_account_name with either storage_account_key or sas_token is required."
      end

      true
    end
  end
end
