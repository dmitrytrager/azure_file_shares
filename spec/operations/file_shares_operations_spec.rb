RSpec.describe AzureFileShares::Operations::FileSharesOperations do
  let(:client) { instance_double(AzureFileShares::Client) }
  subject { described_class.new(client) }

  before do
    allow(client).to receive(:subscription_id).and_return("test-subscription-id")
    allow(client).to receive(:resource_group_name).and_return("test-resource-group")
    allow(client).to receive(:storage_account_name).and_return("test-storage-account")
    allow(client).to receive(:api_version).and_return("2024-01-01")
    allow(client).to receive(:base_url).and_return("https://management.azure.com")
    allow(client).to receive(:access_token).and_return("test-token")
    allow(client).to receive(:connection).and_return(double)
  end

  describe "#list" do
    let(:response_body) do
      {
        "value" => [
          sample_file_share_response("share1"),
          sample_file_share_response("share2"),
        ],
      }
    end

    it "makes a request to the correct endpoint" do
      expected_path = "/subscriptions/test-subscription-id" \
                      "/resourceGroups/test-resource-group" \
                      "/providers/Microsoft.Storage" \
                      "/storageAccounts/test-storage-account" \
                      "/fileServices/default/shares"

      expect(subject).to receive(:request)
        .with(:get, expected_path, {})
        .and_return(response_body)

      subject.list
    end

    it "returns an array of FileShare objects" do
      allow(subject).to receive(:request).and_return(response_body)

      shares = subject.list

      expect(shares).to be_an(Array)
      expect(shares.size).to eq(2)
      expect(shares.all? { |s| s.is_a?(AzureFileShares::Resources::FileShare) }).to be true
      expect(shares.map(&:name)).to contain_exactly("share1", "share2")
    end

    it "passes query parameters to the request" do
      options = { maxpagesize: 10, filter: "name eq 'test'" }

      expect(subject).to receive(:request)
        .with(:get, anything, options)
        .and_return(response_body)

      subject.list(options)
    end

    it "handles empty response" do
      allow(subject).to receive(:request).and_return({})

      shares = subject.list

      expect(shares).to be_an(Array)
      expect(shares).to be_empty
    end
  end

  describe "#get" do
    let(:share_name) { "testshare" }
    let(:response_body) { sample_file_share_response(share_name) }

    it "makes a request to the correct endpoint" do
      expected_path = "/subscriptions/test-subscription-id" \
                      "/resourceGroups/test-resource-group" \
                      "/providers/Microsoft.Storage" \
                      "/storageAccounts/test-storage-account" \
                      "/fileServices/default/shares/#{share_name}"

      expect(subject).to receive(:request)
        .with(:get, expected_path, {})
        .and_return(response_body)

      subject.get(share_name)
    end

    it "returns a FileShare object" do
      allow(subject).to receive(:request).and_return(response_body)

      share = subject.get(share_name)

      expect(share).to be_a(AzureFileShares::Resources::FileShare)
      expect(share.name).to eq(share_name)
    end

    it "passes query parameters to the request" do
      options = { expand: "deleted" }

      expect(subject).to receive(:request)
        .with(:get, anything, options)
        .and_return(response_body)

      subject.get(share_name, options)
    end
  end

  describe "#create" do
    let(:share_name) { "testshare" }
    let(:properties) { { shareQuota: 5120, accessTier: "Hot" } }
    let(:response_body) { sample_file_share_response(share_name) }

    it "makes a request to the correct endpoint" do
      expected_path = "/subscriptions/test-subscription-id" \
                      "/resourceGroups/test-resource-group" \
                      "/providers/Microsoft.Storage" \
                      "/storageAccounts/test-storage-account" \
                      "/fileServices/default/shares/#{share_name}"

      expected_body = {
        properties: properties,
      }

      expect(subject).to receive(:request)
        .with(:put, expected_path, {}, expected_body)
        .and_return(response_body)

      subject.create(share_name, properties)
    end

    it "returns a FileShare object" do
      allow(subject).to receive(:request).and_return(response_body)

      share = subject.create(share_name, properties)

      expect(share).to be_a(AzureFileShares::Resources::FileShare)
      expect(share.name).to eq(share_name)
    end
  end

  describe "#update" do
    let(:share_name) { "testshare" }
    let(:properties) { { shareQuota: 10240 } }
    let(:response_body) { sample_file_share_response(share_name) }

    it "makes a request to the correct endpoint" do
      expected_path = "/subscriptions/test-subscription-id" \
                      "/resourceGroups/test-resource-group" \
                      "/providers/Microsoft.Storage" \
                      "/storageAccounts/test-storage-account" \
                      "/fileServices/default/shares/#{share_name}"

      expected_body = {
        properties: properties,
      }

      expect(subject).to receive(:request)
        .with(:patch, expected_path, {}, expected_body)
        .and_return(response_body)

      subject.update(share_name, properties)
    end

    it "returns a FileShare object" do
      allow(subject).to receive(:request).and_return(response_body)

      share = subject.update(share_name, properties)

      expect(share).to be_a(AzureFileShares::Resources::FileShare)
      expect(share.name).to eq(share_name)
    end
  end

  describe "#delete" do
    let(:share_name) { "testshare" }

    it "makes a request to the correct endpoint" do
      expected_path = "/subscriptions/test-subscription-id" \
                      "/resourceGroups/test-resource-group" \
                      "/providers/Microsoft.Storage" \
                      "/storageAccounts/test-storage-account" \
                      "/fileServices/default/shares/#{share_name}"

      expect(subject).to receive(:request)
        .with(:delete, expected_path, {})
        .and_return({})

      subject.delete(share_name)
    end

    it "returns true on success" do
      allow(subject).to receive(:request).and_return({})

      result = subject.delete(share_name)
      expect(result).to be true
    end

    it "includes delete_snapshots option if provided" do
      options = { delete_snapshots: true }
      expected_options = { deleteSnapshots: true }

      expect(subject).to receive(:request)
        .with(:delete, anything, expected_options)
        .and_return({})

      subject.delete(share_name, options)
    end
  end
end
