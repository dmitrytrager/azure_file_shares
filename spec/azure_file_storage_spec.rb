RSpec.describe AzureFileShares do
  it "has a version number" do
    expect(AzureFileShares::VERSION).not_to be nil
  end

  describe ".configure" do
    it "yields a configuration object" do
      expect { |b| AzureFileShares.configure(&b) }.to yield_with_args(
        instance_of(AzureFileShares::Configuration)
      )
    end

    it "returns the configuration" do
      config = AzureFileShares.configure
      expect(config).to be_a(AzureFileShares::Configuration)
    end

    it "stores the configuration" do
      AzureFileShares.configure do |config|
        config.tenant_id = "my-tenant-id"
      end

      expect(AzureFileShares.configuration.tenant_id).to eq("my-tenant-id")
    end
  end

  describe ".client" do
    it "returns a client instance" do
      expect(AzureFileShares.client).to be_a(AzureFileShares::Client)
    end

    it "memoizes the client instance" do
      client1 = AzureFileShares.client
      client2 = AzureFileShares.client

      expect(client1).to be(client2)
    end
  end

  describe ".reset" do
    it "resets the configuration" do
      AzureFileShares.configure do |config|
        config.tenant_id = "custom-tenant-id"
      end

      AzureFileShares.reset

      expect(AzureFileShares.configuration.tenant_id).not_to eq("custom-tenant-id")
      expect(AzureFileShares.configuration).to be_a(AzureFileShares::Configuration)
    end
  end
end
