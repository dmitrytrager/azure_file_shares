module AzureFileShares
  module Operations
    # Operations for Azure File Share Snapshots
    class SnapshotsOperations < BaseOperation
      # Create a snapshot of a file share
      # @param [String] share_name Name of the file share
      # @param [Hash] metadata Optional metadata for the snapshot
      # @return [AzureFileShares::Resources::FileShareSnapshot] Created snapshot
      def create(share_name, metadata = {})
        path = "#{base_path}/fileServices/default/shares/#{share_name}/snapshots"

        body = {}
        body[:metadata] = metadata unless metadata.empty?

        response = request(:post, path, {}, body)
        AzureFileShares::Resources::FileShareSnapshot.new(response)
      end

      # List snapshots of a file share
      # @param [String] share_name Name of the file share
      # @param [Hash] options Query parameters
      # @return [Array<AzureFileShares::Resources::FileShareSnapshot>] Collection of snapshots
      def list(share_name, options = {})
        path = "#{base_path}/fileServices/default/shares/#{share_name}/snapshots"
        response = request(:get, path, options)

        snapshots = response["value"] || []
        snapshots.map { |snapshot_data| AzureFileShares::Resources::FileShareSnapshot.new(snapshot_data) }
      end

      # Get a specific snapshot by share name and snapshot timestamp
      # @param [String] share_name Name of the file share
      # @param [String] snapshot_timestamp Timestamp of the snapshot
      # @return [AzureFileShares::Resources::FileShareSnapshot] Snapshot details
      def get(share_name, snapshot_timestamp)
        path = "#{base_path}/fileServices/default/shares/#{share_name}"

        options = {
          sharesnapshot: snapshot_timestamp,
        }

        response = request(:get, path, options)
        AzureFileShares::Resources::FileShareSnapshot.new(response)
      end

      # Delete a specific snapshot
      # @param [String] share_name Name of the file share
      # @param [String] snapshot_timestamp Timestamp of the snapshot
      # @return [Boolean] true if successful
      def delete(share_name, snapshot_timestamp)
        path = "#{base_path}/fileServices/default/shares/#{share_name}"

        options = {
          sharesnapshot: snapshot_timestamp,
        }

        request(:delete, path, options)
        true
      end
    end
  end
end
