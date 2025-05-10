RSpec.describe AzureFileShares::Operations::SnapshotsOperations do
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

  describe "#create" do
    let(:share_name) { "testshare" }
    let(:metadata) { { "created_by" => "test_user" } }
    let(:snapshot_time) { "2023-04-01T12:00:00.0000000Z" }
    let(:response_body) { sample_snapshot_response(share_name, snapshot_time) }

    it "makes a request to the correct endpoint" do
      expected_path = "/subscriptions/test-subscription-id" \
                      "/resourceGroups/test-resource-group" \
                      "/providers/Microsoft.Storage" \
                      "/storageAccounts/test-storage-account" \
                      "/fileServices/default/shares/#{share_name}/snapshots"

      expect(subject).to receive(:request)
        .with(:post, expected_path, {}, anything)
        .and_return(response_body)

      subject.create(share_name)
    end

    it "includes metadata in the request body if provided" do
      expected_body = { metadata: metadata }

      expect(subject).to receive(:request)
        .with(:post, anything, {}, expected_body)
        .and_return(response_body)

      subject.create(share_name, metadata)
    end

    it "returns a FileShareSnapshot object" do
      allow(subject).to receive(:request).and_return(response_body)

      snapshot = subject.create(share_name)

      expect(snapshot).to be_a(AzureFileShares::Resources::FileShareSnapshot)
      expect(snapshot.name).to eq(share_name)
      expect(snapshot.snapshot_time).to eq(snapshot_time)
    end
  end

  describe "#list" do
    let(:share_name) { "testshare" }
    let(:snapshot_time1) { "2023-04-01T12:00:00.0000000Z" }
    let(:snapshot_time2) { "2023-04-02T12:00:00.0000000Z" }
    let(:response_body) do
      {
        "value" => [
          sample_snapshot_response(share_name, snapshot_time1),
          sample_snapshot_response(share_name, snapshot_time2),
        ],
      }
    end

    it "makes a request to the correct endpoint" do
      expected_path = "/subscriptions/test-subscription-id" \
                      "/resourceGroups/test-resource-group" \
                      "/providers/Microsoft.Storage" \
                      "/storageAccounts/test-storage-account" \
                      "/fileServices/default/shares/#{share_name}/snapshots"

      expect(subject).to receive(:request)
        .with(:get, expected_path, {})
        .and_return(response_body)

      subject.list(share_name)
    end

    it "returns an array of FileShareSnapshot objects" do
      allow(subject).to receive(:request).and_return(response_body)

      snapshots = subject.list(share_name)

      expect(snapshots).to be_an(Array)
      expect(snapshots.size).to eq(2)
      expect(snapshots.all? { |s| s.is_a?(AzureFileShares::Resources::FileShareSnapshot) }).to be true
      expect(snapshots.map(&:snapshot_time)).to contain_exactly(snapshot_time1, snapshot_time2)
    end

    it "passes query parameters to the request" do
      options = { maxpagesize: 10 }

      expect(subject).to receive(:request)
        .with(:get, anything, options)
        .and_return(response_body)

      subject.list(share_name, options)
    end

    it "handles empty response" do
      allow(subject).to receive(:request).and_return({})

      snapshots = subject.list(share_name)

      expect(snapshots).to be_an(Array)
      expect(snapshots).to be_empty
    end
  end

  describe "#get" do
    let(:share_name) { "testshare" }
    let(:snapshot_time) { "2023-04-01T12:00:00.0000000Z" }
    let(:response_body) { sample_snapshot_response(share_name, snapshot_time) }

    it "makes a request to the correct endpoint with snapshot parameter" do
      expected_path = "/subscriptions/test-subscription-id" \
                      "/resourceGroups/test-resource-group" \
                      "/providers/Microsoft.Storage" \
                      "/storageAccounts/test-storage-account" \
                      "/fileServices/default/shares/#{share_name}"

      expected_options = { sharesnapshot: snapshot_time }

      expect(subject).to receive(:request)
        .with(:get, expected_path, expected_options)
        .and_return(response_body)

      subject.get(share_name, snapshot_time)
    end

    it "returns a FileShareSnapshot object" do
      allow(subject).to receive(:request).and_return(response_body)

      snapshot = subject.get(share_name, snapshot_time)

      expect(snapshot).to be_a(AzureFileShares::Resources::FileShareSnapshot)
      expect(snapshot.name).to eq(share_name)
      expect(snapshot.snapshot_time).to eq(snapshot_time)
    end
  end

  describe "#delete" do
    let(:share_name) { "testshare" }
    let(:snapshot_time) { "2023-04-01T12:00:00.0000000Z" }

    it "makes a request to the correct endpoint with snapshot parameter" do
      expected_path = "/subscriptions/test-subscription-id" \
                      "/resourceGroups/test-resource-group" \
                      "/providers/Microsoft.Storage" \
                      "/storageAccounts/test-storage-account" \
                      "/fileServices/default/shares/#{share_name}"

      expected_options = { sharesnapshot: snapshot_time }

      expect(subject).to receive(:request)
        .with(:delete, expected_path, expected_options)
        .and_return({})

      subject.delete(share_name, snapshot_time)
    end

    it "returns true on success" do
      allow(subject).to receive(:request).and_return({})

      result = subject.delete(share_name, snapshot_time)
      expect(result).to be true
    end
  end
end
