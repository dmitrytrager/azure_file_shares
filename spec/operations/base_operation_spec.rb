RSpec.describe AzureFileShares::Operations::BaseOperation do
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

  describe "#initialize" do
    it "sets the client" do
      expect(subject.client).to eq(client)
    end
  end

  describe "#base_path" do
    it "returns the correct base path" do
      expected_path = "/subscriptions/test-subscription-id" \
                      "/resourceGroups/test-resource-group" \
                      "/providers/Microsoft.Storage" \
                      "/storageAccounts/test-storage-account"

      expect(subject.send(:base_path)).to eq(expected_path)
    end
  end

  describe "#build_url" do
    it "builds a URL with the path and api version" do
      expected_url = "https://management.azure.com/some/path" \
                     "?api-version=2024-01-01"

      expect(subject.send(:build_url, "/some/path")).to eq(expected_url)
    end

    it "includes additional query parameters" do
      expected_url = "https://management.azure.com/some/path" \
                     "?api-version=2024-01-01" \
                     "&param1=value1&param2=value2"

      params = { param1: "value1", param2: "value2" }
      expect(subject.send(:build_url, "/some/path", params)).to eq(expected_url)
    end

    it "encodes query parameter values" do
      expected_url = "https://management.azure.com/some/path" \
                     "?api-version=2024-01-01" \
                     "&param=value+with+spaces"

      params = { param: "value with spaces" }
      expect(subject.send(:build_url, "/some/path", params)).to eq(expected_url)
    end
  end

  describe "#request" do
    let(:connection) { instance_double(Faraday::Connection) }
    let(:request) { instance_double(Faraday::Request) }
    let(:response) { instance_double(Faraday::Response) }

    before do
      allow(client).to receive(:connection).and_return(connection)
      allow(connection).to receive(:get).and_yield(request).and_return(response)
      allow(connection).to receive(:post).and_yield(request).and_return(response)
      allow(connection).to receive(:put).and_yield(request).and_return(response)
      allow(connection).to receive(:delete).and_yield(request).and_return(response)

      allow(request).to receive(:url)
      allow(request).to receive(:headers).and_return({})
      allow(request).to receive(:body=)

      allow(response).to receive(:status).and_return(200)
      allow(response).to receive(:body).and_return('{"result": "success"}')
    end

    it "makes a request with the correct method" do
      expect(connection).to receive(:get)
      subject.send(:request, :get, "/some/path")

      expect(connection).to receive(:post)
      subject.send(:request, :post, "/some/path")

      expect(connection).to receive(:put)
      subject.send(:request, :put, "/some/path")

      expect(connection).to receive(:delete)
      subject.send(:request, :delete, "/some/path")
    end

    it "builds the URL with path and params" do
      expect(request).to receive(:url).with("https://management.azure.com/some/path?api-version=2024-01-01&param=value")
      subject.send(:request, :get, "/some/path", { param: "value" })
    end

    it "sets the authorization header" do
      headers = {}
      allow(request).to receive(:headers).and_return(headers)

      subject.send(:request, :get, "/some/path")
      expect(headers["Authorization"]).to eq("Bearer test-token")
    end

    it "sets the content type header" do
      headers = {}
      allow(request).to receive(:headers).and_return(headers)

      subject.send(:request, :get, "/some/path")
      expect(headers["Content-Type"]).to eq("application/json")
    end

    it "sets the body for POST/PUT requests" do
      expect(request).to receive(:body=).with('{"key":"value"}')

      subject.send(:request, :post, "/some/path", {}, { key: "value" })
    end

    it "returns the parsed JSON response" do
      result = subject.send(:request, :get, "/some/path")
      expect(result).to eq({ "result" => "success" })
    end
  end

  describe "#handle_response" do
    let(:response) { instance_double(Faraday::Response) }

    context "with successful response" do
      before do
        allow(response).to receive(:status).and_return(200)
      end

      it "returns an empty hash for empty response bodies" do
        allow(response).to receive(:body).and_return("")
        result = subject.send(:handle_response, response)
        expect(result).to eq({})

        allow(response).to receive(:body).and_return(nil)
        result = subject.send(:handle_response, response)
        expect(result).to eq({})
      end

      it "returns the parsed JSON for JSON response bodies" do
        allow(response).to receive(:body).and_return('{"key":"value"}')
        result = subject.send(:handle_response, response)
        expect(result).to eq({ "key" => "value" })
      end

      it "returns the raw body if it's not valid JSON" do
        allow(response).to receive(:body).and_return("not json")
        result = subject.send(:handle_response, response)
        expect(result).to eq("not json")
      end
    end

    context "with error response" do
      before do
        allow(response).to receive(:status).and_return(400)
        allow(response).to receive(:reason_phrase).and_return("Bad Request")
      end

      it "raises an ApiError with the error message from the response" do
        allow(response).to receive(:body).and_return('{"error":{"message":"Invalid request"}}')

        expect { subject.send(:handle_response, response) }.to raise_error(
          AzureFileShares::Errors::ApiError,
          "API Error (400): Invalid request"
        )
      end

      it "uses the reason phrase if no error message in response" do
        allow(response).to receive(:body).and_return('{"error":{}}')

        expect { subject.send(:handle_response, response) }.to raise_error(
          AzureFileShares::Errors::ApiError,
          "API Error (400): Bad Request"
        )
      end

      it "handles non-JSON error responses" do
        allow(response).to receive(:body).and_return("Error occurred")

        expect { subject.send(:handle_response, response) }.to raise_error(
          AzureFileShares::Errors::ApiError,
          "API Error (400): Bad Request"
        )
      end
    end
  end
end
