RSpec.describe AzureFileShares::Resources::FileShareSnapshot do
  let(:snapshot_time) { "2023-04-01T12:00:00.0000000Z" }
  let(:snapshot_data) { sample_snapshot_response("testshare", snapshot_time) }

  subject { described_class.new(snapshot_data) }

  describe "#initialize" do
    it "sets basic attributes from response data" do
      expect(subject.id).to eq(snapshot_data["id"])
      expect(subject.name).to eq("testshare")
      expect(subject.type).to eq(snapshot_data["type"])
      expect(subject.etag).to eq(snapshot_data["etag"])
      expect(subject.properties).to eq(snapshot_data["properties"])
    end

    it "parses share name from id" do
      expect(subject.share_name).to eq("testshare")
    end

    it "extracts snapshot time from properties" do
      expect(subject.snapshot_time).to eq(snapshot_time)
    end

    it "handles missing id" do
      snapshot = described_class.new({
        "name" => "testshare",
        "properties" => { "snapshot" => snapshot_time },
      })

      expect(snapshot.share_name).to be_nil
      expect(snapshot.snapshot_time).to eq(snapshot_time)
    end
  end

  describe "property accessors" do
    it "#quota returns shareQuota" do
      expect(subject.quota).to eq(5120)
    end

    it "#timestamp returns snapshot timestamp" do
      expect(subject.timestamp).to eq(snapshot_time)
    end

    it "#creation_time returns parsed time" do
      time = subject.creation_time
      expect(time).to be_a(Time)
      expect(time.utc.iso8601).to eq("2023-04-01T12:00:00Z")
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      hash = subject.to_h
      expect(hash).to be_a(Hash)
      expect(hash[:id]).to eq(subject.id)
      expect(hash[:name]).to eq(subject.name)
      expect(hash[:properties]).to eq(subject.properties)
      expect(hash[:share_name]).to eq("testshare")
      expect(hash[:snapshot_time]).to eq(snapshot_time)
    end
  end

  context "with invalid time format" do
    before do
      snapshot_data["properties"]["creationTime"] = "invalid-time"
    end

    it "returns nil for #creation_time" do
      expect(subject.creation_time).to be_nil
    end
  end
end
