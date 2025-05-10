module AzureFileShares
  # Client for interacting with the Azure File Shares API
  class Client
    attr_reader :configuration

    # Delegate configuration methods to configuration object
    %i[
      tenant_id client_id client_secret subscription_id
      resource_group_name storage_account_name api_version
      base_url request_timeout logger
    ].each do |method|
      define_method(method) do
        configuration.send(method)
      end
    end

    # Initialize a new client
    # @param [AzureFileShares::Configuration] configuration Client configuration
    def initialize(configuration = nil)
      @configuration = configuration || AzureFileShares.configuration
      @configuration.validate!
      @token_provider = if @configuration.tenant_id && @configuration.client_id && @configuration.client_secret
        Auth::TokenProvider.new(
          @configuration.tenant_id,
          @configuration.client_id,
          @configuration.client_secret
        )
      end
      @connection = nil
      @operations = {}
    end

    # Storage account key from configuration
    # @return [String] Storage account key
    def storage_account_key
      @configuration.storage_account_key
    end

    # Get the HTTP connection
    # @return [Faraday::Connection] Faraday connection
    def connection
      @connection ||= create_connection
    end

    # Get an access token for authentication
    # @return [String] Access token
    # @raise [AzureFileShares::Errors::ConfigurationError] if OAuth credentials are missing
    def access_token
      if @token_provider.nil?
        raise AzureFileShares::Errors::ConfigurationError,
          "OAuth credentials (tenant_id, client_id, client_secret) are required for ARM operations"
      end
      @token_provider.access_token
    end

    # Get a FileSharesOperations instance
    # @return [AzureFileShares::Operations::FileSharesOperations]
    def file_shares
      @operations[:file_shares] ||= Operations::FileSharesOperations.new(self)
    end

    # Get a SnapshotsOperations instance
    # @return [AzureFileShares::Operations::SnapshotsOperations]
    def snapshots
      @operations[:snapshots] ||= Operations::SnapshotsOperations.new(self)
    end

    # Get a FileOperations instance
    # @return [AzureFileShares::Operations::FileOperations]
    def files
      @operations[:files] ||= Operations::FileOperations.new(self)
    end

    private

    # Create a new Faraday connection
    # @return [Faraday::Connection] Faraday connection
    def create_connection
      Faraday.new do |conn|
        conn.options.timeout = configuration.request_timeout
        conn.request :json
        conn.response :json, content_type: /\bjson$/
        conn.response :logger, configuration.logger if configuration.logger
        conn.request :retry, {
          max: 3,
          interval: 0.5,
          interval_randomness: 0.5,
          backoff_factor: 2,
          exceptions: [
            Faraday::ConnectionFailed,
            Faraday::TimeoutError,
            Faraday::SSLError,
          ],
        }
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
