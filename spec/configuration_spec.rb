RSpec.describe AzureFileShares::Configuration do
  subject { described_class.new }

  it "initializes with default values" do
    expect(subject.api_version).to eq(AzureFileShares::Configuration::DEFAULT_API_VERSION)
    expect(subject.base_url).to eq(AzureFileShares::Configuration::DEFAULT_BASE_URL)
    expect(subject.request_timeout).to eq(60)
    expect(subject.logger).to be_nil
  end

  describe "#validate!" do
    context "when required fields are missing" do
      it "raises an error for missing tenant_id" do
        subject.client_id = "client-id"
        subject.client_secret = "client-secret"
        subject.subscription_id = "subscription-id"

        expect { subject.validate! }.to raise_error(
          AzureFileShares::Errors::ConfigurationError,
          /Missing required configuration: tenant_id/
        )
      end

      it "raises an error for missing client_id" do
        subject.tenant_id = "tenant-id"
        subject.client_secret = "client-secret"
        subject.subscription_id = "subscription-id"

        expect { subject.validate! }.to raise_error(
          AzureFileShares::Errors::ConfigurationError,
          /Missing required configuration: client_id/
        )
      end

      it "raises an error for missing client_secret" do
        subject.tenant_id = "tenant-id"
        subject.client_id = "client-id"
        subject.subscription_id = "subscription-id"

        expect { subject.validate! }.to raise_error(
          AzureFileShares::Errors::ConfigurationError,
          /Missing required configuration: client_secret/
        )
      end

      it "raises an error for missing subscription_id" do
        subject.tenant_id = "tenant-id"
        subject.client_id = "client-id"
        subject.client_secret = "client-secret"

        expect { subject.validate! }.to raise_error(
          AzureFileShares::Errors::ConfigurationError,
          /Missing required configuration: subscription_id/
        )
      end

      it "raises an error with multiple missing fields" do
        subject.tenant_id = "tenant-id"

        expect { subject.validate! }.to raise_error(
          AzureFileShares::Errors::ConfigurationError,
          /Missing required configuration: client_id, client_secret, subscription_id/
        )
      end
    end

    context "when all required fields are present" do
      it "returns true" do
        subject.tenant_id = "tenant-id"
        subject.client_id = "client-id"
        subject.client_secret = "client-secret"
        subject.subscription_id = "subscription-id"

        expect(subject.validate!).to be true
      end
    end
  end
end
