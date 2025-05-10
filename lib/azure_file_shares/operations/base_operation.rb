module AzureFileShares
  module Operations
    # Base class for all API operations
    class BaseOperation
      attr_reader :client

      # Initialize a new operation with a client
      # @param [AzureFileShares::Client] client The API client
      def initialize(client)
        @client = client
      end

      private

      # Build the base path for storage account operations
      # @return [String] Base path
      def base_path
        "/subscriptions/#{client.subscription_id}" \
          "/resourceGroups/#{client.resource_group_name}" \
          "/providers/Microsoft.Storage" \
          "/storageAccounts/#{client.storage_account_name}"
      end

      # Build the full request URL
      # @param [String] path The API endpoint path
      # @return [String] Full URL
      def build_url(path, params = {})
        url = URI.join(client.base_url, path).to_s
        url += "?api-version=#{client.api_version}"

        params.each do |key, value|
          url += "&#{key}=#{URI.encode_www_form_component(value.to_s)}"
        end

        url
      end

      # Send a request to the API
      # @param [Symbol] method HTTP method (:get, :post, :put, :delete, etc.)
      # @param [String] path API endpoint path
      # @param [Hash] params Query parameters to include in the URL
      # @param [Hash] body Request body (for POST, PUT, PATCH)
      # @return [Hash] Parsed JSON response
      # @raise [AzureFileShares::Errors::ApiError] If the request fails
      def request(method, path, params = {}, body = nil)
        url = build_url(path, params)

        response = client.connection.public_send(method) do |req|
          req.url url
          req.headers["Authorization"] = "Bearer #{client.access_token}"
          req.headers["Content-Type"] = "application/json"
          req.body = JSON.generate(body) if body
        end

        handle_response(response)
      end

      # Handle the API response, raising errors when necessary
      # @param [Faraday::Response] response The HTTP response
      # @return [Hash, Array] Parsed JSON response
      # @raise [AzureFileShares::Errors::ApiError] If the request fails
      def handle_response(response)
        puts "Response: #{response.inspect}"
        case response.status
        when 200..299
          return {} if response.body.nil? || response.body.empty?

          begin
            JSON.parse(response.body)
          rescue JSON::ParserError
            response.body
          end
        else
          error_message = begin
            error_data = JSON.parse(response.body)
            error_data.dig("error", "message") || response.reason_phrase
          rescue JSON::ParserError
            response.reason_phrase || "Unknown error"
          end

          raise AzureFileShares::Errors::ApiError.new(
            "API Error (#{response.status}): #{error_message}",
            response.status,
            response.body
          )
        end
      end
    end
  end
end
