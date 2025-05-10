module AzureFileShares
  module Resources
    # Represents an Azure File Share Snapshot resource
    class FileShareSnapshot
      attr_reader :id, :name, :type, :etag, :properties, :metadata, :share_name, :snapshot_time

      # Initialize a new FileShareSnapshot object from API response
      # @param [Hash] data API response data
      def initialize(data)
        @id = data["id"]
        @name = data["name"]
        @type = data["type"]
        @etag = data["etag"]
        @properties = data["properties"] || {}
        @metadata = data["metadata"] || {}

        # Extract snapshot time from properties directly
        @snapshot_time = properties["snapshot"] if properties && properties["snapshot"]

        # Extract share name and snapshot time from the ID
        parse_id if @id
      end

      # Get the provisioned capacity in GiB
      # @return [Integer] Quota in GiB
      def quota
        properties["shareQuota"]
      end

      # Get the snapshot timestamp
      # @return [String] Snapshot timestamp
      def timestamp
        properties["snapshot"]
      end

      # Get the creation time
      # @return [Time, nil] Creation time or nil if not available
      def creation_time
        time_str = properties["creationTime"]
        Time.parse(time_str) if time_str
      rescue ArgumentError, TypeError
        nil
      end

      # Convert object to a hash
      # @return [Hash] The snapshot as a hash
      def to_h
        {
          id: id,
          name: name,
          type: type,
          etag: etag,
          properties: properties,
          metadata: metadata,
          share_name: share_name,
          snapshot_time: snapshot_time,
        }
      end

      private

      # Parse the resource ID to extract share name
      def parse_id
        return unless id

        parts = id.split("/")
        # Find the index of 'shares' and get the next part as the share name
        shares_index = parts.index("shares")
        if shares_index && shares_index < parts.length - 1
          @share_name = parts[shares_index + 1]
        end
      end
    end
  end
end
