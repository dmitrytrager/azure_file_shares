module AzureFileShares
  module Errors
    # Base error class for API-related errors
    class ApiError < StandardError
      attr_reader :status, :response

      # Initialize a new API error
      # @param [String] message Error message
      # @param [Integer] status HTTP status code
      # @param [Hash] response Full response object
      def initialize(message = nil, status = nil, response = nil)
        @status = status
        @response = response
        super(message)
      end
    end
  end
end
