module AzureFileShares
  module Operations
    # Operations for Azure File Shares
    class FileSharesOperations < BaseOperation
      # List all file shares in the storage account
      # @param [Hash] options Query parameters
      # @option options [Integer] :maxpagesize The maximum items per page
      # @option options [String] :filter Filter string
      # @return [Array<AzureFileShares::Resources::FileShare>] Collection of file shares
      def list(options = {})
        path = "#{base_path}/fileServices/default/shares"
        response = request(:get, path, options)

        shares = response["value"] || []
        shares.map { |share_data| AzureFileShares::Resources::FileShare.new(share_data) }
      end

      # Get a specific file share by name
      # @param [String] share_name Name of the file share
      # @param [Hash] options Query parameters
      # @return [AzureFileShares::Resources::FileShare] File share details
      def get(share_name, options = {})
        path = "#{base_path}/fileServices/default/shares/#{share_name}"
        response = request(:get, path, options)

        AzureFileShares::Resources::FileShare.new(response)
      end

      # Create a new file share
      # @param [String] share_name Name of the file share
      # @param [Hash] properties Share properties
      # @option properties [Integer] :shareQuota The maximum size of the share in GiB
      # @option properties [String] :accessTier Access tier (Hot, Cool, Premium)
      # @option properties [Boolean] :enabledProtocols Enabled protocols (SMB, NFS)
      # @return [AzureFileShares::Resources::FileShare] Created file share
      def create(share_name, properties = {})
        path = "#{base_path}/fileServices/default/shares/#{share_name}"

        body = {
          properties: properties,
        }

        response = request(:put, path, {}, body)
        AzureFileShares::Resources::FileShare.new(response)
      end

      # Update an existing file share
      # @param [String] share_name Name of the file share
      # @param [Hash] properties Share properties to update
      # @return [AzureFileShares::Resources::FileShare] Updated file share
      def update(share_name, properties = {})
        path = "#{base_path}/fileServices/default/shares/#{share_name}"

        body = {
          properties: properties,
        }

        response = request(:patch, path, {}, body)
        AzureFileShares::Resources::FileShare.new(response)
      end

      # Delete a file share
      # @param [String] share_name Name of the file share
      # @param [Hash] options Query parameters
      # @option options [Boolean] :delete_snapshots Whether to delete snapshots
      # @return [Boolean] true if successful
      def delete(share_name, options = {})
        path = "#{base_path}/fileServices/default/shares/#{share_name}"

        delete_options = {}
        delete_options[:deleteSnapshots] = options[:delete_snapshots] if options[:delete_snapshots]

        request(:delete, path, delete_options)
        true
      end
    end
  end
end
