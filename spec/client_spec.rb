RSpec.describe AzureFileShares::Client do
  let(:config) { AzureFileShares.configuration }
  subject { described_class.new(config) }

  before do
    allow_any_instance_of(AzureFileShares::Auth::TokenProvider).to receive(:access_token).and_return("test-token")
  end

  describe "#initialize" do
    it "uses the provided configuration" do
      custom_config = AzureFileShares::Configuration.new
      custom_config.tenant_id = "custom-tenant-id"
      custom_config.client_id = "custom-client-id"
      custom_config.client_secret = "custom-client-secret"
      custom_config.subscription_id = "custom-subscription-id"

      client = described_class.new(custom_config)
      expect(client.tenant_id).to eq("custom-tenant-id")
    end

    it "uses the global configuration if none provided" do
      AzureFileShares.configure do |c|
        c.tenant_id = "global-tenant-id"
      end

      client = described_class.new
      expect(client.tenant_id).to eq("global-tenant-id")
    end

    it "validates the configuration" do
      invalid_config = AzureFileShares::Configuration.new

      expect { described_class.new(invalid_config) }.to raise_error(
        AzureFileShares::Errors::ConfigurationError
      )
    end
  end

  describe "configuration delegation" do
    %i[
      tenant_id client_id client_secret subscription_id
      resource_group_name storage_account_name api_version
      base_url request_timeout logger
    ].each do |method|
      it "delegates #{method} to configuration" do
        allow(config).to receive(method).and_return("test-value")
        expect(subject.send(method)).to eq("test-value")
      end
    end
  end

  describe "#connection" do
    it "creates a Faraday connection" do
      expect(subject.connection).to be_a(Faraday::Connection)
    end

    it "memoizes the connection" do
      conn1 = subject.connection
      conn2 = subject.connection

      expect(conn1).to be(conn2)
    end
  end

  describe "#access_token" do
    it "returns the token from token provider" do
      expect(subject.access_token).to eq("test-token")
    end
  end

  describe "#file_shares" do
    it "returns a FileSharesOperations instance" do
      expect(subject.file_shares).to be_a(AzureFileShares::Operations::FileSharesOperations)
    end

    it "memoizes the operations instance" do
      ops1 = subject.file_shares
      ops2 = subject.file_shares

      expect(ops1).to be(ops2)
    end
  end

  describe "#snapshots" do
    it "returns a SnapshotsOperations instance" do
      expect(subject.snapshots).to be_a(AzureFileShares::Operations::SnapshotsOperations)
    end

    it "memoizes the operations instance" do
      ops1 = subject.snapshots
      ops2 = subject.snapshots

      expect(ops1).to be(ops2)
    end
  end
end
