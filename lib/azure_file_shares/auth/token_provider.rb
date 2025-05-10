module AzureFileShares
  module Auth
    # Handles authentication with Azure AD to retrieve access tokens
    class TokenProvider
      # Azure AD authentication endpoint
      TOKEN_ENDPOINT = "https://login.microsoftonline.com/%s/oauth2/v2.0/token"
      # Default token expiry buffer in seconds (5 minutes)
      TOKEN_EXPIRY_BUFFER = 300
      # Default resource scope
      DEFAULT_SCOPE = "https://management.azure.com/.default"

      attr_reader :tenant_id, :client_id, :client_secret, :scope

      # Initialize a new TokenProvider
      # @param [String] tenant_id Azure tenant ID
      # @param [String] client_id Azure client ID (application ID)
      # @param [String] client_secret Azure client secret
      # @param [String] scope Resource scope, defaults to management.azure.com
      def initialize(tenant_id, client_id, client_secret, scope = DEFAULT_SCOPE)
        @tenant_id = tenant_id
        @client_id = client_id
        @client_secret = client_secret
        @scope = scope
        @token = nil
        @token_expires_at = nil
      end

      # Get a valid access token, refreshing if necessary
      # @return [String] Access token
      def access_token
        refresh_token if token_expired?
        @token
      end

      private

      # Check if the current token is expired or will expire soon
      # @return [Boolean] true if token needs refresh
      def token_expired?
        return true if @token.nil? || @token_expires_at.nil?

        Time.now.to_i >= (@token_expires_at - TOKEN_EXPIRY_BUFFER)
      end

      # Refresh the access token
      # @return [String] New access token
      def refresh_token
        endpoint = format(TOKEN_ENDPOINT, tenant_id)

        response = Faraday.new(url: endpoint) do |conn|
          conn.request :url_encoded
          conn.adapter Faraday.default_adapter
        end.post do |req|
          req.body = {
            client_id: client_id,
            client_secret: client_secret,
            grant_type: "client_credentials",
            scope: scope,
          }
        end

        handle_token_response(response)
      end

      # Handle the token response from Azure AD
      # @param [Faraday::Response] response The HTTP response
      # @return [String] Access token
      # @raise [AzureFileShares::Errors::ApiError] If token request fails
      def handle_token_response(response)
        if response.status != 200
          raise AzureFileShares::Errors::ApiError.new(
            "Failed to obtain access token: #{response.body}",
            response.status,
            response.body
          )
        end

        data = JSON.parse(response.body)
        @token = data["access_token"]
        # Subtract a small buffer from expiry time to ensure token validity
        @token_expires_at = Time.now.to_i + data["expires_in"].to_i
        @token
      rescue JSON::ParserError => e
        raise AzureFileShares::Errors::ApiError.new(
          "Failed to parse token response: #{e.message}",
          response.status,
          response.body
        )
      end
    end
  end
end
