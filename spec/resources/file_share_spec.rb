RSpec.describe AzureFileShares::Resources::FileShare do
  let(:share_data) { sample_file_share_response("testshare") }
  subject { described_class.new(share_data) }

  describe "#initialize" do
    it "sets basic attributes from response data" do
      expect(subject.id).to eq(share_data["id"])
      expect(subject.name).to eq("testshare")
      expect(subject.type).to eq(share_data["type"])
      expect(subject.etag).to eq(share_data["etag"])
      expect(subject.properties).to eq(share_data["properties"])
    end

    it "handles empty properties and metadata" do
      share = described_class.new({
        "id" => "/subscriptions/test/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/test/fileServices/default/shares/empty",
        "name" => "empty",
      })

      expect(share.properties).to eq({})
      expect(share.metadata).to eq({})
    end
  end

  describe "property accessors" do
    it "#quota returns shareQuota" do
      expect(subject.quota).to eq(5120)
    end

    it "#access_tier returns accessTier" do
      expect(subject.access_tier).to eq("TransactionOptimized")
    end

    it "#last_modified_time returns parsed time" do
      time = subject.last_modified_time
      expect(time).to be_a(Time)
      expect(time.utc.iso8601).to eq("2023-04-01T10:00:00Z")
    end

    it "#creation_time returns nil if not present" do
      expect(subject.creation_time).to be_nil
    end

    it "#enabled_protocols returns enabled protocols" do
      expect(subject.enabled_protocols).to eq("SMB")
    end

    it "#lease_state returns lease state" do
      expect(subject.lease_state).to eq("available")
    end

    it "#lease_status returns lease status" do
      expect(subject.lease_status).to eq("unlocked")
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      hash = subject.to_h
      expect(hash).to be_a(Hash)
      expect(hash[:id]).to eq(subject.id)
      expect(hash[:name]).to eq(subject.name)
      expect(hash[:properties]).to eq(subject.properties)
    end
  end

  context "with invalid time format" do
    before do
      share_data["properties"]["lastModifiedTime"] = "invalid-time"
    end

    it "returns nil for #last_modified_time" do
      expect(subject.last_modified_time).to be_nil
    end
  end
end
