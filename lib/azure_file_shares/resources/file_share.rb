module AzureFileShares
  module Resources
    # Represents an Azure File Share resource
    class FileShare
      attr_reader :id, :name, :type, :etag, :properties, :metadata

      # Initialize a new FileShare object from API response
      # @param [Hash] data API response data
      def initialize(data)
        @id = data["id"]
        @name = data["name"]
        @type = data["type"]
        @etag = data["etag"]
        @properties = data["properties"] || {}
        @metadata = data["metadata"] || {}
      end

      # Get the provisioned capacity in GiB
      # @return [Integer] Quota in GiB
      def quota
        properties["shareQuota"]
      end

      # Get the access tier (Hot, Cool, Premium)
      # @return [String] Access tier
      def access_tier
        properties["accessTier"]
      end

      # Get the last modified time
      # @return [Time, nil] Last modified time or nil if not available
      def last_modified_time
        time_str = properties["lastModifiedTime"]
        Time.parse(time_str) if time_str
      rescue ArgumentError, TypeError
        nil
      end

      # Get the creation time
      # @return [Time, nil] Creation time or nil if not available
      def creation_time
        time_str = properties["creationTime"]
        Time.parse(time_str) if time_str
      rescue ArgumentError, TypeError
        nil
      end

      # Get the enabled protocols
      # @return [String] Enabled protocols (SMB, NFS)
      def enabled_protocols
        properties["enabledProtocols"]
      end

      # Get the lease state
      # @return [String] Lease state
      def lease_state
        properties["leaseState"]
      end

      # Get the lease status
      # @return [String] Lease status
      def lease_status
        properties["leaseStatus"]
      end

      # Convert object to a hash
      # @return [Hash] The file share as a hash
      def to_h
        {
          id: id,
          name: name,
          type: type,
          etag: etag,
          properties: properties,
          metadata: metadata,
        }
      end
    end
  end
end
