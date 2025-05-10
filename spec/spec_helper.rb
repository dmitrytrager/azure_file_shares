require "azure_file_shares"
require "bundler/setup"
require "debug"
require "webmock/rspec"
require "vcr"

# Configure VCR for recording HTTP interactions
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Filter out sensitive information from VCR cassettes
  config.filter_sensitive_data("<TENANT_ID>") { ENV["AZURE_TENANT_ID"] }
  config.filter_sensitive_data("<CLIENT_ID>") { ENV["AZURE_CLIENT_ID"] }
  config.filter_sensitive_data("<CLIENT_SECRET>") { ENV["AZURE_CLIENT_SECRET"] }
  config.filter_sensitive_data("<SUBSCRIPTION_ID>") { ENV["AZURE_SUBSCRIPTION_ID"] }
  config.filter_sensitive_data("<RESOURCE_GROUP>") { ENV["AZURE_RESOURCE_GROUP"] }
  config.filter_sensitive_data("<STORAGE_ACCOUNT>") { ENV["AZURE_STORAGE_ACCOUNT"] }
  config.filter_sensitive_data("<ACCESS_TOKEN>") { |interaction|
    if interaction.request.headers["Authorization"]&.first
      interaction.request.headers["Authorization"].first.gsub(/^Bearer\s+/, "")
    end
  }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Set up test configuration
  config.before(:each) do
    AzureFileShares.reset

    # Set up a test configuration if environment variables are available
    AzureFileShares.configure do |c|
      c.tenant_id = ENV["AZURE_TENANT_ID"] || "test-tenant-id"
      c.client_id = ENV["AZURE_CLIENT_ID"] || "test-client-id"
      c.client_secret = ENV["AZURE_CLIENT_SECRET"] || "test-client-secret"
      c.subscription_id = ENV["AZURE_SUBSCRIPTION_ID"] || "test-subscription-id"
      c.resource_group_name = ENV["AZURE_RESOURCE_GROUP"] || "test-resource-group"
      c.storage_account_name = ENV["AZURE_STORAGE_ACCOUNT"] || "teststorageaccount"
    end
  end
end

# Helper method to create a test file share response
def sample_file_share_response(share_name = "testshare")
  {
    "id" => "/subscriptions/test-subscription-id/resourceGroups/test-resource-group" \
           "/providers/Microsoft.Storage/storageAccounts/teststorageaccount" \
           "/fileServices/default/shares/#{share_name}",
    "name" => share_name,
    "type" => "Microsoft.Storage/storageAccounts/fileServices/shares",
    "etag" => "\"0x8D9EDCBF3E3E100\"",
    "properties" => {
      "shareQuota" => 5120,
      "accessTier" => "TransactionOptimized",
      "enabledProtocols" => "SMB",
      "lastModifiedTime" => "2023-04-01T10:00:00.0000000Z",
      "leaseStatus" => "unlocked",
      "leaseState" => "available",
    },
  }
end

# Helper method to create a test file share snapshot response
def sample_snapshot_response(share_name = "testshare", snapshot_time = "2023-04-01T12:00:00.0000000Z")
  {
    "id" => "/subscriptions/test-subscription-id/resourceGroups/test-resource-group" \
           "/providers/Microsoft.Storage/storageAccounts/teststorageaccount" \
           "/fileServices/default/shares/#{share_name}",
    "name" => share_name,
    "type" => "Microsoft.Storage/storageAccounts/fileServices/shares",
    "etag" => "\"0x8D9EDCBF3E3E200\"",
    "properties" => {
      "shareQuota" => 5120,
      "snapshot" => snapshot_time,
      "enabledProtocols" => "SMB",
      "creationTime" => "2023-04-01T12:00:00.0000000Z",
    },
  }
end
