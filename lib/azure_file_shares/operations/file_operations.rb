module AzureFileShares
  module Operations
    # Operations for Azure File Shares - File and Directory Operations
    class FileOperations < BaseOperation
      # Base URL for Azure File storage API
      # @return [String] File API base URL
      def file_base_url
        "https://#{client.storage_account_name}.file.core.windows.net"
      end

      # Create a directory in a file share
      # @param [String] share_name Name of the file share
      # @param [String] directory_path Path to the directory to create
      # @param [Hash] options Additional options
      # @return [Boolean] true if successful
      def create_directory(share_name, directory_path, options = {})
        ensure_storage_credentials!
        path = build_file_path(share_name, directory_path)

        # Use direct approach for directory creation
        url = "#{file_base_url}#{path}?restype=directory"

        # Create headers with authorization
        headers = {
          "x-ms-date" => Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT"),
          "x-ms-version" => client.api_version,
          "Content-Type" => "application/x-www-form-urlencoded",
        }

        # Add additional headers from options if provided
        options.each do |key, value|
          headers["x-ms-#{key}"] = value.to_s unless value.nil?
        end

        # Calculate authorization header with restype query parameter
        auth_header = calculate_authorization_header(:put, path, headers, { restype: "directory" })
        headers["Authorization"] = auth_header if auth_header

        # Log request details if a logger is available
        if client.logger
          client.logger.debug "Azure File API Create Directory Request: PUT #{url}"
          client.logger.debug "Headers: #{headers.reject { |k, _| k == 'Authorization' }.inspect}"
        end

        # Create connection and make the request directly
        connection = create_file_connection

        response = connection.put(url, nil, headers)

        # Check response
        if response.status >= 200 && response.status < 300
          true
        else
          handle_file_response(response)
        end
      end

      # List directories and files in a file share or directory
      # @param [String] share_name Name of the file share
      # @param [String] directory_path Path to the directory (empty string for root)
      # @param [Hash] options Additional options
      # @option options [String] :prefix Filter by prefix
      # @option options [Integer] :maxresults Maximum number of results to return
      # @return [Hash] Hash containing directories and files
      def list(share_name, directory_path = "", options = {})
        ensure_storage_credentials!
        directory_path = normalize_path(directory_path)
        path = build_file_path(share_name, directory_path)

        # Build URL with query parameters
        url = "#{file_base_url}#{path}?restype=directory&comp=list"

        # Add additional query parameters
        url += "&prefix=#{URI.encode_www_form_component(options[:prefix])}" if options[:prefix]
        url += "&maxresults=#{options[:maxresults]}" if options[:maxresults]

        # Query parameters for authorization
        query_params = { restype: "directory", comp: "list" }
        query_params[:prefix] = options[:prefix] if options[:prefix]
        query_params[:maxresults] = options[:maxresults] if options[:maxresults]

        # Create headers with authorization
        headers = {
          "x-ms-date" => Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT"),
          "x-ms-version" => client.api_version,
        }

        # Calculate authorization header
        auth_header = calculate_authorization_header(:get, path, headers, query_params)
        headers["Authorization"] = auth_header if auth_header

        # Log request details if a logger is available
        if client.logger
          client.logger.debug "Azure File API Request: GET #{url}"
          client.logger.debug "Headers: #{headers.reject { |k, _| k == 'Authorization' }.inspect}"
        end

        # Create connection and make the request directly
        connection = create_file_connection

        response = connection.get(url, nil, headers)

        # Check response
        if response.status >= 200 && response.status < 300
          # Parse the XML response
          parse_list_response(response.body)
        else
          handle_file_response(response)
        end
      end

      # Check if a directory exists
      # @param [String] share_name Name of the file share
      # @param [String] directory_path Path to the directory
      # @return [Boolean] true if directory exists
      def directory_exists?(share_name, directory_path)
        ensure_storage_credentials!
        path = build_file_path(share_name, directory_path)

        # Use direct approach for HEAD requests
        url = "#{file_base_url}#{path}"

        # Add restype parameter
        url += "?restype=directory"

        # Create headers with authorization
        headers = {
          "x-ms-date" => Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT"),
          "x-ms-version" => client.api_version,
        }

        # Calculate authorization header - include restype query parameter
        auth_header = calculate_authorization_header(:head, path, headers, { restype: "directory" })
        headers["Authorization"] = auth_header if auth_header

        # Create connection and make the request directly
        connection = create_file_connection

        begin
          response = connection.head(url, nil, headers)
          response.status >= 200 && response.status < 300
        rescue Faraday::Error, AzureFileShares::Errors::ApiError => _e
          false
        end
      end

      # Delete a directory
      # @param [String] share_name Name of the file share
      # @param [String] directory_path Path to the directory
      # @param [Hash] options Additional options
      # @option options [Boolean] :recursive Whether to delete recursively
      # @return [Boolean] true if successful
      def delete_directory(share_name, directory_path, options = {})
        ensure_storage_credentials!
        path = build_file_path(share_name, directory_path)

        # Build URL with query parameters
        url = "#{file_base_url}#{path}?restype=directory"

        # Add recursive parameter if specified
        url += "&recursive=true" if options[:recursive]

        # Query parameters for authorization
        query_params = { restype: "directory" }
        query_params[:recursive] = "true" if options[:recursive]

        # Create headers with authorization
        headers = {
          "x-ms-date" => Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT"),
          "x-ms-version" => client.api_version,
        }

        # Calculate authorization header
        auth_header = calculate_authorization_header(:delete, path, headers, query_params)
        headers["Authorization"] = auth_header if auth_header

        # Create connection and make the request directly
        connection = create_file_connection

        response = connection.delete(url, nil, headers)

        # Check response
        if response.status >= 200 && response.status < 300
          true
        else
          handle_file_response(response)
        end
      end

      # Upload a file to a file share
      # @param [String] share_name Name of the file share
      # @param [String] directory_path Path to the directory (empty string for root)
      # @param [String] file_name Name of the file
      # @param [String, IO] content File content or IO object
      # @param [Hash] options Additional options
      # @option options [String] :content_type Content type of the file
      # @option options [Hash] :metadata Metadata for the file
      # @return [Boolean] true if successful
      def upload_file(share_name, directory_path, file_name, content, options = {})
        ensure_storage_credentials!
        directory_path = normalize_path(directory_path)
        file_path = File.join(directory_path, file_name)
        path = build_file_path(share_name, file_path)

        # Get content length and convert to string if needed
        content_length = nil
        if content.is_a?(IO) || content.is_a?(StringIO)
          content_length = content.size
          content.rewind
          content = content.read
        else
          content_length = content.bytesize
        end

        # 1. Create the file with specified size
        create_url = "#{file_base_url}#{path}"

        # Create headers for file creation
        create_headers = {
          "x-ms-date" => Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT"),
          "x-ms-version" => client.api_version,
          "x-ms-type" => "file",
          "x-ms-content-length" => content_length.to_s,
          "Content-Type" => "application/x-www-form-urlencoded",
        }

        # Set content type if provided
        create_headers["x-ms-content-type"] = options[:content_type] || "application/octet-stream"

        # Add metadata if provided
        if options[:metadata] && !options[:metadata].empty?
          options[:metadata].each do |key, value|
            create_headers["x-ms-meta-#{key.to_s.downcase}"] = value.to_s
          end
        end

        # Calculate authorization header for file creation
        auth_header = calculate_authorization_header(:put, path, create_headers, {})
        create_headers["Authorization"] = auth_header if auth_header

        # Log request details if a logger is available
        if client.logger
          client.logger.debug "Azure File API Create File Request: PUT #{create_url}"
          client.logger.debug "Headers: #{create_headers.reject { |k, _| k == 'Authorization' }.inspect}"
        end

        # Create connection and make the request to create the file
        connection = create_file_connection
        create_response = connection.put(create_url, nil, create_headers)

        # Check create response
        unless create_response.status >= 200 && create_response.status < 300
          handle_file_response(create_response)
        end

        # 2. Upload the content (for small files - large files would use ranges)
        range_url = "#{file_base_url}#{path}?comp=range"

        # Create headers for content upload
        range_headers = {
          "x-ms-date" => Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT"),
          "x-ms-version" => client.api_version,
          "x-ms-write" => "update",
          "x-ms-range" => "bytes=0-#{content_length - 1}",
          "Content-Length" => content_length.to_s,
          "Content-Type" => "application/x-www-form-urlencoded",
        }

        # Calculate authorization header for range upload
        range_auth_header = calculate_authorization_header(:put, path, range_headers, { comp: "range" })
        range_headers["Authorization"] = range_auth_header if range_auth_header

        # Log request details if a logger is available
        if client.logger
          client.logger.debug "Azure File API Upload Range Request: PUT #{range_url}"
          client.logger.debug "Headers: #{range_headers.reject { |k, _| k == 'Authorization' }.inspect}"
          client.logger.debug "Content length: #{content_length}"
        end

        # Make the request to upload the content
        range_response = connection.put(range_url, content, range_headers)

        # Check range response
        if range_response.status >= 200 && range_response.status < 300
          true
        else
          handle_file_response(range_response)
        end
      end

      # Download a file from a file share
      # @param [String] share_name Name of the file share
      # @param [String] directory_path Path to the directory (empty string for root)
      # @param [String] file_name Name of the file
      # @param [Hash] options Additional options
      # @option options [Range] :range Range of bytes to download
      # @return [String] File content
      def download_file(share_name, directory_path, file_name, options = {})
        ensure_storage_credentials!
        directory_path = normalize_path(directory_path)
        file_path = File.join(directory_path, file_name)
        path = build_file_path(share_name, file_path)

        # Build URL
        url = "#{file_base_url}#{path}"

        # Create headers with authorization
        headers = {
          "x-ms-date" => Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT"),
          "x-ms-version" => client.api_version,
        }

        # Add range header if specified
        if options[:range]
          headers["x-ms-range"] = "bytes=#{options[:range].begin}-#{options[:range].end}"
        end

        # Calculate authorization header
        auth_header = calculate_authorization_header(:get, path, headers, {})
        headers["Authorization"] = auth_header if auth_header

        # Log request details if a logger is available
        if client.logger
          client.logger.debug "Azure File API Download Request: GET #{url}"
          client.logger.debug "Headers: #{headers.reject { |k, _| k == 'Authorization' }.inspect}"
        end

        # Create connection and make the request directly
        connection = create_file_connection

        response = connection.get(url, nil, headers)

        # Check response
        if response.status >= 200 && response.status < 300
          response.body
        else
          handle_file_response(response)
        end
      end

      # Check if a file exists
      # @param [String] share_name Name of the file share
      # @param [String] directory_path Path to the directory (empty string for root)
      # @param [String] file_name Name of the file
      # @return [Boolean] true if file exists
      def file_exists?(share_name, directory_path, file_name)
        ensure_storage_credentials!
        directory_path = normalize_path(directory_path)
        file_path = File.join(directory_path, file_name)
        path = build_file_path(share_name, file_path)

        # Use the same direct approach as get_file_properties for HEAD requests
        url = "#{file_base_url}#{path}"

        # Create headers with authorization
        headers = {
          "x-ms-date" => Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT"),
          "x-ms-version" => client.api_version,
        }

        # Calculate authorization header
        auth_header = calculate_authorization_header(:head, path, headers, {})
        headers["Authorization"] = auth_header if auth_header

        # Create connection and make the request directly
        connection = create_file_connection

        begin
          response = connection.head(url, nil, headers)
          response.status >= 200 && response.status < 300
        rescue Faraday::Error, AzureFileShares::Errors::ApiError => _e
          false
        end
      end

      # Get file properties
      # @param [String] share_name Name of the file share
      # @param [String] directory_path Path to the directory (empty string for root)
      # @param [String] file_name Name of the file
      # @return [Hash] File properties
      def get_file_properties(share_name, directory_path, file_name)
        ensure_storage_credentials!
        directory_path = normalize_path(directory_path)
        file_path = File.join(directory_path, file_name)
        path = build_file_path(share_name, file_path)

        # For HEAD requests, we need to handle the response directly in file_request
        # to capture the headers but not process the body
        url = "#{file_base_url}#{path}"

        # Create headers with authorization
        headers = {
          "x-ms-date" => Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT"),
          "x-ms-version" => client.api_version,
        }

        # Calculate authorization header
        auth_header = calculate_authorization_header(:head, path, headers, {})
        headers["Authorization"] = auth_header if auth_header

        # Create connection and make the request directly
        connection = create_file_connection
        response = connection.head(url, nil, headers)

        # If the request failed, raise an error
        unless response.status >= 200 && response.status < 300
          handle_file_response(response)
        end

        # Extract properties from response headers
        {
          content_length: response.headers["content-length"].to_i,
          content_type: response.headers["content-type"],
          last_modified: response.headers["last-modified"],
          etag: response.headers["etag"],
          metadata: extract_metadata(response.headers),
        }
      end

      # Delete a file
      # @param [String] share_name Name of the file share
      # @param [String] directory_path Path to the directory (empty string for root)
      # @param [String] file_name Name of the file
      # @return [Boolean] true if successful
      def delete_file(share_name, directory_path, file_name)
        ensure_storage_credentials!
        directory_path = normalize_path(directory_path)
        file_path = File.join(directory_path, file_name)
        path = build_file_path(share_name, file_path)

        # Build URL
        url = "#{file_base_url}#{path}"

        # Create headers with authorization
        headers = {
          "x-ms-date" => Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT"),
          "x-ms-version" => client.api_version,
        }

        # Calculate authorization header
        auth_header = calculate_authorization_header(:delete, path, headers, {})
        headers["Authorization"] = auth_header if auth_header

        # Log request details if a logger is available
        if client.logger
          client.logger.debug "Azure File API Delete File Request: DELETE #{url}"
          client.logger.debug "Headers: #{headers.reject { |k, _| k == 'Authorization' }.inspect}"
        end

        # Create connection and make the request directly
        connection = create_file_connection

        response = connection.delete(url, nil, headers)

        # Check response
        if response.status >= 200 && response.status < 300
          true
        else
          handle_file_response(response)
        end
      end

      # Copy a file within the storage account
      # @param [String] source_share_name Source share name
      # @param [String] source_directory_path Source directory path
      # @param [String] source_file_name Source file name
      # @param [String] dest_share_name Destination share name
      # @param [String] dest_directory_path Destination directory path
      # @param [String] dest_file_name Destination file name
      # @return [Boolean] true if successful
      def copy_file(source_share_name, source_directory_path, source_file_name,
                    dest_share_name, dest_directory_path, dest_file_name)
        ensure_storage_credentials!

        # Build source file URL
        source_directory_path = normalize_path(source_directory_path)
        source_file_path = File.join(source_directory_path, source_file_name)
        source_path = build_file_path(source_share_name, source_file_path)
        source_url = "#{file_base_url}#{source_path}"

        # Build destination path
        dest_directory_path = normalize_path(dest_directory_path)
        dest_file_path = File.join(dest_directory_path, dest_file_name)
        dest_path = build_file_path(dest_share_name, dest_file_path)

        # Build URL
        url = "#{file_base_url}#{dest_path}"

        # Create headers with authorization
        headers = {
          "x-ms-date" => Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT"),
          "x-ms-version" => client.api_version,
          "x-ms-copy-source" => source_url,
          "Content-Type" => "application/x-www-form-urlencoded",
          # "Content-Length" => "0",
        }

        # Calculate authorization header
        auth_header = calculate_authorization_header(:put, dest_path, headers, {})
        headers["Authorization"] = auth_header if auth_header

        # Log request details if a logger is available
        if client.logger
          client.logger.debug "Azure File API Copy File Request: PUT #{url}"
          client.logger.debug "Headers: #{headers.reject { |k, _| k == 'Authorization' }.inspect}"
          client.logger.debug "Source URL: #{source_url}"
        end

        # Create connection and make the request directly
        connection = create_file_connection

        response = connection.put(url, nil, headers)

        # Check response
        if response.status >= 200 && response.status < 300
          true
        else
          handle_file_response(response)
        end
      end

      private

      # Ensure storage credentials are set
      def ensure_storage_credentials!
        unless client.storage_account_name
          raise AzureFileShares::Errors::ConfigurationError, "Storage account name is required"
        end

        unless client.storage_account_key
          raise AzureFileShares::Errors::ConfigurationError, "Storage account key is required for file operations"
        end
      end

      # Normalize a directory path by removing leading/trailing slashes
      # @param [String] path Directory path
      # @return [String] Normalized path
      def normalize_path(path)
        return "" if path.nil? || path.empty? || path == "/"
        path = path.start_with?("/") ? path[1..-1] : path
        path = path.end_with?("/") ? path[0..-2] : path
        path.split("/").map { |seg| URI.encode_www_form_component(seg) }.join("/")
      end

      # Build a file API path
      # @param [String] share_name Share name
      # @param [String] path File or directory path
      # @return [String] Full path
      def build_file_path(share_name, path)
        path = normalize_path(path)
        "/#{share_name}/#{path}"
      end

      # Format metadata for request headers
      # @param [Hash] metadata Metadata hash
      # @return [Hash] Formatted metadata headers
      def format_metadata(metadata)
        return {} unless metadata && !metadata.empty?

        formatted = {}
        metadata.each do |key, value|
          formatted["x-ms-meta-#{key.to_s.downcase}"] = value.to_s
        end
        formatted
      end

      # Extract metadata from response headers
      # @param [Hash] headers Response headers
      # @return [Hash] Extracted metadata
      def extract_metadata(headers)
        metadata = {}
        headers.each do |key, value|
          if key.to_s.downcase.start_with?("x-ms-meta-")
            metadata_key = key.to_s.downcase.sub("x-ms-meta-", "")
            metadata[metadata_key] = value
          end
        end
        metadata
      end

      # Parse the list directories and files response
      # @param [String] response XML response
      # @return [Hash] Parsed directories and files
      def parse_list_response(response)
        require "nokogiri"

        xml = Nokogiri::XML(response)

        # Extract directories
        directories = xml.xpath("//Entries/Directory").map do |dir|
          {
            name: dir.at_xpath("Name").text,
            properties: {
              last_modified: dir.at_xpath("Properties/Last-Modified")&.text,
              etag: dir.at_xpath("Properties/Etag")&.text,
            },
          }
        end

        # Extract files
        files = xml.xpath("//Entries/File").map do |file|
          {
            name: file.at_xpath("Name").text,
            properties: {
              content_length: file.at_xpath("Properties/Content-Length")&.text.to_i,
              content_type: file.at_xpath("Properties/Content-Type")&.text,
              last_modified: file.at_xpath("Properties/Last-Modified")&.text,
              etag: file.at_xpath("Properties/Etag")&.text,
            },
          }
        end

        { directories: directories, files: files }
      end

      # Calculate authorization header for Azure Storage REST API
      # @param [Symbol] method HTTP method
      # @param [String] path API endpoint path
      # @param [Hash] headers Request headers
      # @param [Hash] query_params Query parameters from the request
      # @return [String] Authorization header value
      def calculate_authorization_header(method, path, headers, query_params = {})
        # Normalize headers
        headers = headers.transform_keys(&:downcase)

        # Ensure required headers
        headers["x-ms-date"] ||= Time.now.httpdate
        headers["x-ms-version"] ||= "2025-01-05"
        # headers["content-length"] = headers["content-length"].to_s == "0" ? "0" : headers["content-length"].to_s

        # Merge with actual headers
        canonicalized_headers = headers
          .select { |k, _| k.downcase.start_with?("x-ms-") }
          .map { |k, v| "#{k.downcase.strip}:#{v.strip}" }
          .sort
          .join("\n")

        # Canonicalized resource
        canonicalized_resource = "/#{client.storage_account_name}#{path}"
        if query_params.any?
          query_string = query_params
            .group_by { |k, _| k.downcase }
            .transform_values { |v| v.map { |_, val| val }.flatten }
            .sort
            .map { |k, v| "#{k}:#{Array(v).sort.join(',')}" }
            .join("\n")

          canonicalized_resource += "\n#{query_string}"
        end

        string_to_sign = [
          method.to_s.upcase,
          headers["content-encoding"] || "",
          headers["content-language"] || "",
          headers["content-length"] || "",
          headers["content-md5"] || "",
          headers["content-type"] || "",
          "", # Date (empty because x-ms-date is used instead)
          headers["if-modified-since"] || "",
          headers["if-match"] || "",
          headers["if-none-match"] || "",
          headers["if-unmodified-since"] || "",
          headers["range"] || "",
          canonicalized_headers,
          canonicalized_resource,
        ].join("\n")

        # Log the string to sign for debugging
        if client.logger
          client.logger.debug "String-to-sign line count: #{string_to_sign.lines.count}"
          client.logger.debug "String to sign for authorization (with escapes): #{string_to_sign.inspect}"
        end

        decoded_key = Base64.decode64(client.storage_account_key)
        signature = OpenSSL::HMAC.digest("sha256", decoded_key, string_to_sign.encode("utf-8"))
        encoded_signature = Base64.strict_encode64(signature)

        "SharedKey #{client.storage_account_name}:#{encoded_signature}"
      end

      # Create a connection for file operations
      # @return [Faraday::Connection] Faraday connection
      def create_file_connection
        Faraday.new do |conn|
          conn.options.timeout = client.request_timeout || 60
          conn.options.open_timeout = 10

          # Enable response logging if a logger is set
          if client.logger
            conn.response :logger, client.logger, { headers: true, bodies: false } do |logger|
              logger.filter(/(Authorization: "Bearer )([^"]+)/, '\1[FILTERED]')
              logger.filter(/(SharedKey [^:]+:)([^"]+)/, '\1[FILTERED]')
            end
          end

          # Add retry middleware for transient failures
          conn.request :retry, {
            max: 3,
            interval: 0.5,
            interval_randomness: 0.5,
            backoff_factor: 2,
            retry_statuses: [ 408, 429, 500, 502, 503, 504 ],
            methods: [ :get, :head, :put, :delete, :post ],
            exceptions: [
              Faraday::ConnectionFailed,
              Faraday::TimeoutError,
              Errno::ETIMEDOUT,
              "Timeout::Error",
            ],
          }

          conn.adapter Faraday.default_adapter
        end
      end

      # Handle the file API response
      # @param [Faraday::Response] response HTTP response
      # @return [String, Hash] Response body or parsed response
      # @raise [AzureFileShares::Errors::ApiError] If the request fails
      def handle_file_response(response)
        case response.status
        when 200..299
          return {} if response.body.nil? || response.body.empty?

          if response.headers["content-type"]&.include?("application/xml")
            response.body # Return XML as string for the caller to parse
          else
            response.body
          end
        else
          error_message = "File API Error (#{response.status}): #{response.reason_phrase}"

          begin
            if response.headers["content-type"]&.include?("application/xml")
              require "nokogiri"
              xml = Nokogiri::XML(response.body)
              error_code = xml.at_xpath("//Code")&.text
              error_message_text = xml.at_xpath("//Message")&.text
              error_message = "File API Error (#{response.status}): #{error_code} - #{error_message_text}"
            end
          rescue StandardError => _e
            # Ignore parsing errors
          end

          raise AzureFileShares::Errors::ApiError.new(
            error_message,
            response.status,
            response.body
          )
        end
      end
    end
  end
end
