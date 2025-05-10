require "nokogiri"

RSpec.describe AzureFileShares::Operations::FileOperations do
  let(:storage_account_name) { "teststorageaccount" }
  let(:storage_account_key) { "dGVzdGtleQ==" }  # Base64 encoded "testkey"
  let(:client) { instance_double(AzureFileShares::Client) }
  let(:connection) { instance_double("Faraday::Connection") }
  let(:file_base_url) { subject.file_base_url }

  subject { described_class.new(client) }

  before do
    allow(client).to receive(:subscription_id).and_return("test-subscription-id")
    allow(client).to receive(:resource_group_name).and_return("test-resource-group")
    allow(client).to receive(:storage_account_name).and_return(storage_account_name)
    allow(client).to receive(:storage_account_key).and_return(storage_account_key)
    allow(client).to receive(:api_version).and_return("2024-01-01")
    allow(client).to receive(:base_url).and_return("https://management.azure.com")
    allow(client).to receive(:request_timeout).and_return(60)
    allow(client).to receive(:logger).and_return(nil)
  end

  describe "#file_base_url" do
    it "returns the correct file base URL" do
      expected_url = "https://#{storage_account_name}.file.core.windows.net"
      expect(subject.file_base_url).to eq(expected_url)
    end
  end

  describe "#ensure_storage_credentials!" do
    context "when storage account name is missing" do
      before { allow(client).to receive(:storage_account_name).and_return(nil) }

      it "raises a ConfigurationError" do
        expect { subject.send(:ensure_storage_credentials!) }.to raise_error(
          AzureFileShares::Errors::ConfigurationError,
          "Storage account name is required"
        )
      end
    end

    context "when storage account key is missing" do
      before { allow(client).to receive(:storage_account_key).and_return(nil) }

      it "raises a ConfigurationError" do
        expect { subject.send(:ensure_storage_credentials!) }.to raise_error(
          AzureFileShares::Errors::ConfigurationError,
          "Storage account key is required for file operations"
        )
      end
    end
  end

  describe "#normalize_path" do
    it "returns empty string for nil path" do
      expect(subject.send(:normalize_path, nil)).to eq("")
    end

    it "returns empty string for empty path" do
      expect(subject.send(:normalize_path, "")).to eq("")
    end

    it "returns empty string for root path" do
      expect(subject.send(:normalize_path, "/")).to eq("")
    end

    it "removes leading slash" do
      expect(subject.send(:normalize_path, "/test")).to eq("test")
    end

    it "removes trailing slash" do
      expect(subject.send(:normalize_path, "test/")).to eq("test")
    end

    it "removes both leading and trailing slashes" do
      expect(subject.send(:normalize_path, "/test/")).to eq("test")
    end

    it "does not modify path without leading or trailing slashes" do
      expect(subject.send(:normalize_path, "path/to/dir")).to eq("path/to/dir")
    end
  end

  describe "#build_file_path" do
    it "builds correct path for root directory" do
      expect(subject.send(:build_file_path, "testshare", "")).to eq("/testshare/")
    end

    it "builds correct path for file in root directory" do
      expect(subject.send(:build_file_path, "testshare", "testfile.txt")).to eq("/testshare/testfile.txt")
    end

    it "builds correct path for file in subdirectory" do
      expect(subject.send(:build_file_path, "testshare", "dir/testfile.txt")).to eq("/testshare/dir/testfile.txt")
    end

    it "normalizes directory paths" do
      expect(subject.send(:build_file_path, "testshare", "/dir/")).to eq("/testshare/dir")
    end
  end

  describe "#format_metadata" do
    it "returns empty hash for nil metadata" do
      expect(subject.send(:format_metadata, nil)).to eq({})
    end

    it "returns empty hash for empty metadata" do
      expect(subject.send(:format_metadata, {})).to eq({})
    end

    it "formats metadata with correct prefix" do
      metadata = { "key1" => "value1", "key2" => "value2" }
      formatted = subject.send(:format_metadata, metadata)

      expect(formatted["x-ms-meta-key1"]).to eq("value1")
      expect(formatted["x-ms-meta-key2"]).to eq("value2")
    end

    it "converts keys and values to strings" do
      metadata = { key1: :value1, key2: 123 }
      formatted = subject.send(:format_metadata, metadata)

      expect(formatted["x-ms-meta-key1"]).to eq("value1")
      expect(formatted["x-ms-meta-key2"]).to eq("123")
    end
  end

  describe "#extract_metadata" do
    it "extracts metadata from headers" do
      headers = {
        "Content-Type" => "text/plain",
        "x-ms-meta-key1" => "value1",
        "x-ms-meta-key2" => "value2",
        "X-MS-META-KEY3" => "value3",
      }

      metadata = subject.send(:extract_metadata, headers)

      expect(metadata).to eq({
        "key1" => "value1",
        "key2" => "value2",
        "key3" => "value3",
      })
    end

    it "returns empty hash when no metadata headers" do
      headers = { "Content-Type" => "text/plain" }
      expect(subject.send(:extract_metadata, headers)).to eq({})
    end
  end

  describe "#create_directory" do
    let(:share_name) { "testshare" }
    let(:directory_path) { "testdir" }
    let(:connection) { instance_double("Faraday::Connection") }
    let(:response) { instance_double("Faraday::Response", status: 201) }

    before do
      allow(subject).to receive(:create_file_connection).and_return(connection)
      allow(connection).to receive(:put).and_return(response)
      allow(response).to receive(:status).and_return(201)
      allow(subject).to receive(:calculate_authorization_header).and_return("AUTH")
      allow(subject.client).to receive(:api_version).and_return("2024-01-01")
      allow(subject.client).to receive(:logger).and_return(nil)
    end

    it "makes a PUT request to the correct endpoint with directory restype" do
      expected_path = "/testshare/testdir"
      expected_url = "https://teststorageaccount.file.core.windows.net#{expected_path}?restype=directory"

      expect(connection).to receive(:put).with(
        expected_url,
        nil,
        hash_including(
          "x-ms-version" => "2024-01-01",
          "Content-Type" => "application/x-www-form-urlencoded",
          "Authorization" => "AUTH"
        )
      ).and_return(response)

      subject.create_directory(share_name, directory_path)
    end

    it "returns true on success" do
      allow(response).to receive(:status).and_return(201)
      expect(subject.create_directory(share_name, directory_path)).to be true
    end

    it "passes additional options as headers" do
      options = { timeout: 30 }
      expect(connection).to receive(:put).with(
        anything,
        nil,
        hash_including("x-ms-timeout" => "30")
      ).and_return(response)

      subject.create_directory(share_name, directory_path, options)
    end

    it "normalizes directory paths" do
      expect(connection).to receive(:put).with(
        "https://teststorageaccount.file.core.windows.net/testshare/testdir?restype=directory",
        nil,
        anything
      ).and_return(response)

      subject.create_directory(share_name, "/testdir/")
    end

    it "handles non-successful response" do
      allow(response).to receive(:status).and_return(400)
      expect(subject).to receive(:handle_file_response).with(response).and_return(false)
      expect(subject.create_directory(share_name, directory_path)).to be false
    end
  end

  describe "#directory_exists?" do
    let(:share_name) { "testshare" }
    let(:directory_path) { "testdir" }
    let(:connection) { instance_double("Faraday::Connection") }
    let(:response) { instance_double("Faraday::Response", status: 200) }

    before do
      allow(subject).to receive(:create_file_connection).and_return(connection)
      allow(subject.client).to receive(:api_version).and_return("2024-01-01")
      allow(subject).to receive(:calculate_authorization_header).and_return("AUTH")
    end

    it "makes a HEAD request to the correct endpoint with directory restype" do
      expected_path = "/testshare/testdir"
      expected_url = "https://teststorageaccount.file.core.windows.net#{expected_path}?restype=directory"
      headers = hash_including("Authorization" => "AUTH")

      expect(connection).to receive(:head).with(expected_url, nil, headers).and_return(response)
      allow(response).to receive(:status).and_return(200)

      subject.directory_exists?(share_name, directory_path)
    end

    it "returns true when the request succeeds" do
      allow(connection).to receive(:head).and_return(response)
      allow(response).to receive(:status).and_return(200)
      expect(subject.directory_exists?(share_name, directory_path)).to be true
    end

    it "returns false when the request fails" do
      allow(connection).to receive(:head).and_raise(Faraday::Error)
      expect(subject.directory_exists?(share_name, directory_path)).to be false
    end
  end

  describe "#delete_directory" do
    let(:share_name) { "testshare" }
    let(:directory_path) { "testdir" }
    let(:connection) { instance_double("Faraday::Connection") }
    let(:response) { instance_double("Faraday::Response", status: 202) }

    before do
      allow(subject).to receive(:create_file_connection).and_return(connection)
      allow(subject.client).to receive(:api_version).and_return("2024-01-01")
      allow(subject).to receive(:calculate_authorization_header).and_return("AUTH")
      allow(connection).to receive(:delete).and_return(response)
      allow(response).to receive(:status).and_return(202)
    end

    it "makes a DELETE request to the correct endpoint with directory restype" do
      expected_path = "/testshare/testdir"
      expected_url = "https://teststorageaccount.file.core.windows.net#{expected_path}?restype=directory"
      headers = hash_including("Authorization" => "AUTH")

      expect(connection).to receive(:delete).with(expected_url, nil, headers).and_return(response)
      subject.delete_directory(share_name, directory_path)
    end

    it "adds recursive option when specified" do
      expected_url = "https://teststorageaccount.file.core.windows.net/testshare/testdir?restype=directory&recursive=true"
      headers = hash_including("Authorization" => "AUTH")

      expect(connection).to receive(:delete).with(expected_url, nil, headers).and_return(response)
      subject.delete_directory(share_name, directory_path, recursive: true)
    end

    it "returns true on success" do
      allow(connection).to receive(:delete).and_return(response)
      allow(response).to receive(:status).and_return(202)
      expect(subject.delete_directory(share_name, directory_path)).to be true
    end

    it "handles non-successful response" do
      allow(response).to receive(:status).and_return(400)
      expect(subject).to receive(:handle_file_response).with(response).and_return(false)
      expect(subject.delete_directory(share_name, directory_path)).to be false
    end
  end

  describe "#list" do
    let(:share_name) { "testshare" }
    let(:directory_path) { "testdir" }
    let(:connection) { instance_double("Faraday::Connection") }
    let(:response) { instance_double("Faraday::Response", status: 200, body: "<xml></xml>") }

    before do
      allow(subject).to receive(:create_file_connection).and_return(connection)
      allow(subject.client).to receive(:api_version).and_return("2024-01-01")
      allow(subject).to receive(:calculate_authorization_header).and_return("AUTH")
      allow(connection).to receive(:get).and_return(response)
      allow(response).to receive(:status).and_return(200)
      allow(response).to receive(:body).and_return("<xml></xml>")
      allow(subject).to receive(:parse_list_response).and_return({ directories: [], files: [] })
    end

    it "makes a GET request to the correct endpoint with directory restype and comp=list" do
      expected_path = "/testshare/testdir"
      expected_url = "https://teststorageaccount.file.core.windows.net#{expected_path}?restype=directory&comp=list"
      headers = hash_including("Authorization" => "AUTH")

      expect(connection).to receive(:get).with(expected_url, nil, headers).and_return(response)
      subject.list(share_name, directory_path)
    end

    it "returns parsed response on success" do
      expect(subject).to receive(:parse_list_response).with("<xml></xml>").and_return({ directories: [], files: [] })
      expect(subject.list(share_name, directory_path)).to eq({ directories: [], files: [] })
    end

    it "handles non-successful response" do
      allow(response).to receive(:status).and_return(400)
      expect(subject).to receive(:handle_file_response).with(response).and_return(false)
      expect(subject.list(share_name, directory_path)).to be false
    end
  end

  describe "#upload_file" do
    let(:share_name) { "testshare" }
    let(:directory_path) { "testdir" }
    let(:file_name) { "testfile.txt" }
    let(:content) { "File content for testing" }
    let(:content_length) { content.bytesize }
    let(:connection) { instance_double("Faraday::Connection") }
    let(:create_response) { instance_double("Faraday::Response", status: 201) }
    let(:range_response) { instance_double("Faraday::Response", status: 201) }

    before do
      allow(subject).to receive(:create_file_connection).and_return(connection)
      allow(subject.client).to receive(:api_version).and_return("2024-01-01")
      allow(subject).to receive(:calculate_authorization_header).and_return("AUTH")
      allow(connection).to receive(:put).and_return(create_response, range_response)
      allow(create_response).to receive(:status).and_return(201)
      allow(range_response).to receive(:status).and_return(201)
    end

    it "makes requests to create the file and upload its content" do
      file_path = "/testshare/testdir/testfile.txt"
      create_url = "https://teststorageaccount.file.core.windows.net#{file_path}"
      range_url = "#{create_url}?comp=range"

      expect(connection).to receive(:put).with(
        create_url,
        nil,
        hash_including("x-ms-type" => "file", "x-ms-content-length" => content_length.to_s)
      ).ordered.and_return(create_response)

      expect(connection).to receive(:put).with(
        range_url,
        content,
        hash_including("x-ms-write" => "update", "x-ms-range" => "bytes=0-#{content_length - 1}")
      ).ordered.and_return(range_response)

      subject.upload_file(share_name, directory_path, file_name, content)
    end

    it "returns true on success" do
      expect(subject.upload_file(share_name, directory_path, file_name, content)).to be true
    end
  end

  describe "#download_file" do
    let(:share_name) { "testshare" }
    let(:directory_path) { "testdir" }
    let(:file_name) { "testfile.txt" }
    let(:file_content) { "File content for testing" }
    let(:connection) { instance_double("Faraday::Connection") }
    let(:response) { instance_double("Faraday::Response", status: 200, body: file_content) }

    before do
      allow(subject).to receive(:create_file_connection).and_return(connection)
      allow(subject.client).to receive(:api_version).and_return("2024-01-01")
      allow(subject).to receive(:calculate_authorization_header).and_return("AUTH")
      allow(connection).to receive(:get).and_return(response)
      allow(response).to receive(:status).and_return(200)
      allow(response).to receive(:body).and_return(file_content)
    end

    it "makes a GET request to the file path" do
      file_path = "/testshare/testdir/testfile.txt"
      url = "https://teststorageaccount.file.core.windows.net#{file_path}"
      headers = hash_including("Authorization" => "AUTH")

      expect(connection).to receive(:get).with(url, nil, headers).and_return(response)
      subject.download_file(share_name, directory_path, file_name)
    end

    it "returns the file content" do
      expect(subject.download_file(share_name, directory_path, file_name)).to eq(file_content)
    end
  end

  describe "#file_exists?" do
    let(:share_name) { "testshare" }
    let(:directory_path) { "testdir" }
    let(:file_name) { "testfile.txt" }
    let(:connection) { instance_double("Faraday::Connection") }
    let(:response) { instance_double("Faraday::Response", status: 200) }

    before do
      allow(subject).to receive(:create_file_connection).and_return(connection)
      allow(subject.client).to receive(:api_version).and_return("2024-01-01")
      allow(subject).to receive(:calculate_authorization_header).and_return("AUTH")
    end

    it "makes a HEAD request to the file path" do
      file_path = "/testshare/testdir/testfile.txt"
      url = "https://teststorageaccount.file.core.windows.net#{file_path}"
      headers = hash_including("Authorization" => "AUTH")

      expect(connection).to receive(:head).with(url, nil, headers).and_return(response)
      allow(response).to receive(:status).and_return(200)
      subject.file_exists?(share_name, directory_path, file_name)
    end

    it "returns true when the request succeeds" do
      allow(connection).to receive(:head).and_return(response)
      allow(response).to receive(:status).and_return(200)
      expect(subject.file_exists?(share_name, directory_path, file_name)).to be true
    end

    it "returns false when the request fails" do
      allow(connection).to receive(:head).and_raise(Faraday::Error)
      expect(subject.file_exists?(share_name, directory_path, file_name)).to be false
    end
  end

  describe "#get_file_properties" do
    let(:share_name) { "testshare" }
    let(:directory_path) { "testdir" }
    let(:file_name) { "testfile.txt" }
    let(:connection) { instance_double("Faraday::Connection") }
    let(:response) do
      instance_double(Faraday::Response,
        status: 200,
        headers: {
          "content-length" => "123",
          "content-type" => "text/plain",
          "last-modified" => "Wed, 01 Jan 2023 12:00:00 GMT",
          "etag" => "\"0x8DA1F4D3E72DE2D\"",
          "x-ms-meta-custom1" => "value1",
          "x-ms-meta-custom2" => "value2",
        }
      )
    end

    before do
      allow(subject).to receive(:create_file_connection).and_return(connection)
      allow(subject.client).to receive(:api_version).and_return("2024-01-01")
      allow(subject).to receive(:calculate_authorization_header).and_return("AUTH")
      allow(connection).to receive(:head).and_return(response)
      allow(response).to receive(:status).and_return(200)
      allow(response).to receive(:headers).and_return(response.headers)
    end

    it "makes a HEAD request to the file path" do
      file_path = "/testshare/testdir/testfile.txt"
      url = "https://teststorageaccount.file.core.windows.net#{file_path}"
      headers = hash_including("Authorization" => "AUTH")

      expect(connection).to receive(:head).with(url, nil, headers).and_return(response)
      subject.get_file_properties(share_name, directory_path, file_name)
    end

    it "extracts properties from the response headers" do
      properties = subject.get_file_properties(share_name, directory_path, file_name)

      expect(properties[:content_length]).to eq(123)
      expect(properties[:content_type]).to eq("text/plain")
      expect(properties[:last_modified]).to eq("Wed, 01 Jan 2023 12:00:00 GMT")
      expect(properties[:etag]).to eq("\"0x8DA1F4D3E72DE2D\"")
      expect(properties[:metadata]).to eq({
        "custom1" => "value1",
        "custom2" => "value2",
      })
    end
  end

  describe "#delete_file" do
    let(:share_name) { "testshare" }
    let(:directory_path) { "testdir" }
    let(:file_name) { "testfile.txt" }
    let(:connection) { instance_double("Faraday::Connection") }
    let(:response) { instance_double("Faraday::Response", status: 202) }

    before do
      allow(subject).to receive(:create_file_connection).and_return(connection)
      allow(subject.client).to receive(:api_version).and_return("2024-01-01")
      allow(subject).to receive(:calculate_authorization_header).and_return("AUTH")
      allow(connection).to receive(:delete).and_return(response)
      allow(response).to receive(:status).and_return(202)
    end

    it "makes a DELETE request to the file path" do
      file_path = "/testshare/testdir/testfile.txt"
      url = "https://teststorageaccount.file.core.windows.net#{file_path}"
      headers = hash_including("Authorization" => "AUTH")

      expect(connection).to receive(:delete).with(url, nil, headers).and_return(response)
      subject.delete_file(share_name, directory_path, file_name)
    end

    it "returns true on success" do
      allow(connection).to receive(:delete).and_return(response)
      allow(response).to receive(:status).and_return(202)
      expect(subject.delete_file(share_name, directory_path, file_name)).to be true
    end
  end

  describe "#copy_file" do
    let(:source_share) { "sourceshare" }
    let(:source_dir) { "sourcedir" }
    let(:source_file) { "sourcefile.txt" }
    let(:dest_share) { "destshare" }
    let(:dest_dir) { "destdir" }
    let(:dest_file) { "destfile.txt" }
    let(:connection) { instance_double("Faraday::Connection") }
    let(:response) { instance_double("Faraday::Response", status: 202) }

    before do
      allow(subject).to receive(:create_file_connection).and_return(connection)
      allow(subject.client).to receive(:api_version).and_return("2024-01-01")
      allow(subject).to receive(:calculate_authorization_header).and_return("AUTH")
      allow(connection).to receive(:put).and_return(response)
      allow(response).to receive(:status).and_return(202)
    end

    it "makes a PUT request with x-ms-copy-source header" do
      dest_path = "/destshare/destdir/destfile.txt"
      url = "https://teststorageaccount.file.core.windows.net#{dest_path}"
      headers = hash_including("x-ms-copy-source" => "https://teststorageaccount.file.core.windows.net/sourceshare/sourcedir/sourcefile.txt", "Authorization" => "AUTH")

      expect(connection).to receive(:put).with(url, nil, headers).and_return(response)
      subject.copy_file(source_share, source_dir, source_file, dest_share, dest_dir, dest_file)
    end

    it "returns true on success" do
      expect(subject.copy_file(source_share, source_dir, source_file, dest_share, dest_dir, dest_file)).to be true
    end
  end

  # ... keep your SAS, handle_file_response, and parse_list_response specs as before ...
end
