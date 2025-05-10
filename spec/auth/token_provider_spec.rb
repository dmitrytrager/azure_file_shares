RSpec.describe AzureFileShares::Auth::TokenProvider do
  let(:tenant_id) { "test-tenant-id" }
  let(:client_id) { "test-client-id" }
  let(:client_secret) { "test-client-secret" }

  subject { described_class.new(tenant_id, client_id, client_secret) }

  describe "#access_token" do
    context "when token is not set" do
      let(:token_response) do
        {
          access_token: "test-access-token",
          expires_in: 3600,
          token_type: "Bearer",
        }.to_json
      end

      before do
        stub_request(:post, "https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0/token")
          .to_return(
            status: 200,
            body: token_response,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "requests a new token" do
        expect(subject.access_token).to eq("test-access-token")
      end
    end

    context "when token is set but expired" do
      let(:token_response) do
        {
          access_token: "new-access-token",
          expires_in: 3600,
          token_type: "Bearer",
        }.to_json
      end

      before do
        stub_request(:post, "https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0/token")
          .to_return(
            status: 200,
            body: token_response,
            headers: { "Content-Type" => "application/json" }
          )

        # Set expired token
        subject.instance_variable_set(:@token, "old-access-token")
        subject.instance_variable_set(:@token_expires_at, Time.now.to_i - 60)
      end

      it "refreshes the token" do
        expect(subject.access_token).to eq("new-access-token")
      end
    end

    context "when token is set and valid" do
      before do
        # Set valid token with future expiry
        subject.instance_variable_set(:@token, "valid-access-token")
        subject.instance_variable_set(:@token_expires_at, Time.now.to_i + 1800)
      end

      it "returns the cached token" do
        expect(subject.access_token).to eq("valid-access-token")
      end
    end

    context "when token request fails" do
      before do
        stub_request(:post, "https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0/token")
          .to_return(
            status: 401,
            body: { error: "invalid_client", error_description: "Invalid client credentials" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises an ApiError" do
        expect { subject.access_token }.to raise_error(AzureFileShares::Errors::ApiError) do |error|
          expect(error.status).to eq(401)
          expect(error.message).to include("Failed to obtain access token")
        end
      end
    end

    context "when token response is not valid JSON" do
      before do
        stub_request(:post, "https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0/token")
          .to_return(
            status: 200,
            body: "Not a JSON response",
            headers: { "Content-Type" => "text/plain" }
          )
      end

      it "raises an ApiError" do
        expect { subject.access_token }.to raise_error(AzureFileShares::Errors::ApiError) do |error|
          expect(error.message).to include("Failed to parse token response")
        end
      end
    end
  end
end
