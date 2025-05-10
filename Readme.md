# Azure File Shares

A Ruby gem for interacting with the Microsoft Azure File Shares API. This gem provides a simple, object-oriented interface for managing Azure File Shares and their snapshots, as well as file and directory operations.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'azure_file_shares'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install azure_file_shares
```

## Requirements

- Ruby 2.6 or higher
- Azure account with appropriate permissions
- Registered application in Microsoft Entra ID with API permissions

## Usage

### Configuration Options

The gem supports two main modes of operation, each with different configuration requirements:

### 1. Full Access (ARM API + Storage API)

For complete functionality including share management and file operations:

```ruby
AzureFileShares.configure do |config|
  # Required for ARM operations (share management)
  config.tenant_id = 'your-tenant-id'
  config.client_id = 'your-client-id'
  config.client_secret = 'your-client-secret'
  config.subscription_id = 'your-subscription-id'
  config.resource_group_name = 'your-resource-group-name'
  
  # Required for all operations
  config.storage_account_name = 'your-storage-account-name'
  config.storage_account_key = 'your-storage-account-key'
  
  # Optional settings
  config.api_version = '2024-01-01' # Default
  config.request_timeout = 60 # Default (in seconds)
  config.logger = Logger.new(STDOUT) # Optional
end
```

### 2. File Operations Only (Storage API)

If you only need to work with files and directories within existing shares, you can use this simplified configuration:

```ruby
AzureFileShares.configure do |config|
  # Minimal configuration for file operations
  config.storage_account_name = 'your-storage-account-name'
  config.storage_account_key = 'your-storage-account-key'
end

# Now you can use file operations
client = AzureFileShares.client

# Works with existing shares
client.files.upload_file('share-name', 'path/to/directory', 'file.txt', 'file content')
client.files.list('share-name', 'path/to/directory')
client.files.download_file('share-name', 'path/to/directory', 'file.txt')

# But share management operations will fail
# client.file_shares.list  # This would throw an error
```

With the simplified configuration, you can perform all file and directory operations but cannot manage shares. Share management operations require the full configuration including resource group details.


## Using SAS Tokens for Authentication

For file operations, you can use a Shared Access Signature (SAS) token instead of a storage account key. This is often more reliable and has less stringent permission requirements:

```ruby
# Configure with SAS token
AzureFileShares.configure do |config|
  config.storage_account_name = 'your-storage-account-name'
  config.sas_token = 'sv=2020-08-04&ss=f&srt=co&sp=rwdlc&se=2025-04-30T21:00:00Z&st=2025-04-29T13:00:00Z&spr=https&sig=XXXXXXXXXXXXX'
end

# Or set it on an existing client
client = AzureFileShares.client
client.sas_token = 'sv=2020-08-04&ss=f&srt=co&sp=rwdlc&se=2025-04-30T21:00:00Z&st=2025-04-29T13:00:00Z&spr=https&sig=XXXXXXXXXXXXX'

# Then use file operations as normal
client.files.list('share-name', 'path/to/directory')
```

### Generating a SAS Token

You can generate a SAS token in several ways:

1. **Azure Portal**:
   - Go to your Storage Account
   - Select "File shares" and choose your share
   - Click "Generate SAS" in the top menu
   - Configure permissions and expiry
   - Click "Generate SAS token and URL"
   - Copy just the token part (the query string starting with "?sv=")

2. **Azure CLI**:
   ```bash
   az storage file generate-sas --account-name <storage-account> --account-key <account-key> --path <file-path> --share-name <share-name> --permissions r --expiry <expiry-date>
   ```

3. **Azure PowerShell**:
   ```powershell
   New-AzStorageFileSASToken -Context $ctx -ShareName <share-name> -Path <file-path> -Permission r -ExpiryTime <expiry-date>
   ```

4. **Programmatically** using this gem:
   ```ruby
   sas_url = AzureFileShares.client.files.generate_file_sas_url(
     'share-name',
     'path/to/directory',
     'file.txt',
     expiry: Time.now + 86400, # 1 day
     permissions: 'r'          # Read-only
   )
   ```

Using SAS tokens can be more reliable than Shared Key authentication and provides more granular control over permissions and access duration.

### Working with File Shares

#### Listing File Shares

```ruby
# Get all file shares in the storage account
shares = AzureFileShares.client.file_shares.list

# Get shares with pagination and filtering
shares = AzureFileShares.client.file_shares.list(
  maxpagesize: 10,
  filter: "properties/shareQuota gt 5120"
)

# Access share properties
shares.each do |share|
  puts "Share: #{share.name}"
  puts "  Quota: #{share.quota} GiB"
  puts "  Access Tier: #{share.access_tier}"
  puts "  Last Modified: #{share.last_modified_time}"
end
```

#### Getting a Specific Share

```ruby
# Get a specific file share by name
share = AzureFileShares.client.file_shares.get('my-share-name')
```

#### Creating a New Share

```ruby
# Create a new file share with default settings
share = AzureFileShares.client.file_shares.create('new-share-name')

# Create a new file share with specific settings
share = AzureFileShares.client.file_shares.create(
  'new-share-name',
  {
    shareQuota: 5120, # 5 TB quota
    accessTier: 'Hot',
    enabledProtocols: 'SMB'
  }
)
```

#### Updating a Share

```ruby
# Update an existing file share
updated_share = AzureFileShares.client.file_shares.update(
  'my-share-name',
  {
    shareQuota: 10240, # 10 TB quota
    accessTier: 'Cool'
  }
)
```

#### Deleting a Share

```ruby
# Delete a file share
AzureFileShares.client.file_shares.delete('my-share-name')

# Delete a file share and its snapshots
AzureFileShares.client.file_shares.delete('my-share-name', delete_snapshots: true)
```

### Working with Snapshots

#### Creating a Snapshot

```ruby
# Create a snapshot of a file share
snapshot = AzureFileShares.client.snapshots.create('my-share-name')

# Create a snapshot with metadata
snapshot = AzureFileShares.client.snapshots.create(
  'my-share-name',
  {
    'created_by' => 'backup_service',
    'backup_id' => '12345'
  }
)

# Access snapshot details
puts "Snapshot created at: #{snapshot.timestamp}"
puts "Creation time: #{snapshot.creation_time}"
```

#### Listing Snapshots for a Share

```ruby
# List all snapshots for a file share
snapshots = AzureFileShares.client.snapshots.list('my-share-name')

# List snapshots with pagination
snapshots = AzureFileShares.client.snapshots.list('my-share-name', maxpagesize: 10)
```

#### Getting a Specific Snapshot

```ruby
# Get a specific snapshot by share name and snapshot timestamp
snapshot = AzureFileShares.client.snapshots.get(
  'my-share-name',
  '2023-04-01T12:00:00.0000000Z'
)
```

#### Deleting a Snapshot

```ruby
# Delete a specific snapshot
AzureFileShares.client.snapshots.delete(
  'my-share-name',
  '2023-04-01T12:00:00.0000000Z'
)
```

## Working with Files and Directories

Before using file operations, make sure to set up your storage account key:

```ruby
# Configure with storage account key
AzureFileShares.configure do |config|
  # Basic configuration as above
  config.storage_account_key = 'your-storage-account-key'
end

# Or set it on an existing client
AzureFileShares.client.storage_account_key = 'your-storage-account-key'
```

### Directory Operations

```ruby
# Create a directory
AzureFileShares.client.files.create_directory('my-share-name', 'path/to/directory')

# Check if a directory exists
if AzureFileShares.client.files.directory_exists?('my-share-name', 'path/to/directory')
  puts "Directory exists"
end

# List files and directories
contents = AzureFileShares.client.files.list('my-share-name', 'path/to/directory')

# Access directories
contents[:directories].each do |dir|
  puts "Directory: #{dir[:name]}"
  puts "  Last Modified: #{dir[:properties][:last_modified]}"
end

# Access files
contents[:files].each do |file|
  puts "File: #{file[:name]}"
  puts "  Size: #{file[:properties][:content_length]} bytes"
  puts "  Type: #{file[:properties][:content_type]}"
end

# Delete a directory (use recursive: true to delete contents)
AzureFileShares.client.files.delete_directory('my-share-name', 'path/to/directory', recursive: true)
```

### File Operations

#### Uploading Files

```ruby
# Upload a file from a string
content = "This is the content of my file"
AzureFileShares.client.files.upload_file(
  'my-share-name',        # Share name
  'path/to/directory',    # Directory path (use '' for root)
  'myfile.txt',           # File name
  content,                # File content
  content_type: 'text/plain'  # Optional content type
)

# Upload a file from disk
content = File.read('local/path/to/myfile.txt')
AzureFileShares.client.files.upload_file(
  'my-share-name',
  'path/to/directory',
  'myfile.txt',
  content
)

# Upload with metadata
AzureFileShares.client.files.upload_file(
  'my-share-name',
  'path/to/directory',
  'myfile.txt',
  content,
  metadata: {
    'created_by' => 'user123',
    'department' => 'engineering'
  }
)
```

#### Downloading Files

```ruby
# Download a file
content = AzureFileShares.client.files.download_file(
  'my-share-name',
  'path/to/directory',
  'myfile.txt'
)

# Save to disk
File.write('local/path/to/downloaded.txt', content)

# Download a range of bytes
partial_content = AzureFileShares.client.files.download_file(
  'my-share-name',
  'path/to/directory',
  'myfile.txt',
  range: 0..1023  # First 1KB
)
```

#### File Management

```ruby
# Check if a file exists
if AzureFileShares.client.files.file_exists?('my-share-name', 'path/to/directory', 'myfile.txt')
  puts "File exists"
end

# Get file properties
properties = AzureFileShares.client.files.get_file_properties(
  'my-share-name',
  'path/to/directory',
  'myfile.txt'
)

puts "File size: #{properties[:content_length]} bytes"
puts "Content type: #{properties[:content_type]}"
puts "Last modified: #{properties[:last_modified]}"
puts "Metadata: #{properties[:metadata]}"

# Delete a file
AzureFileShares.client.files.delete_file(
  'my-share-name',
  'path/to/directory',
  'myfile.txt'
)

# Copy a file
AzureFileShares.client.files.copy_file(
  'source-share',        # Source share name
  'source/directory',    # Source directory path
  'source-file.txt',     # Source file name
  'dest-share',          # Destination share name
  'dest/directory',      # Destination directory path
  'dest-file.txt'        # Destination file name
)

# Generate a SAS URL for a file (time-limited access)
sas_url = AzureFileShares.client.files.generate_file_sas_url(
  'my-share-name',
  'path/to/directory',
  'myfile.txt',
  expiry: Time.now + 3600,  # 1 hour from now
  permissions: 'r'          # Read-only access
)

puts "Access file at: #{sas_url}"
```

## Error Handling

The gem uses custom error classes to provide meaningful error information:

```ruby
begin
  share = AzureFileShares.client.file_shares.get('non-existent-share')
rescue AzureFileShares::Errors::ApiError => e
  puts "API Error (#{e.status}): #{e.message}"
  puts "Response: #{e.response}"
end

begin
  AzureFileShares.configure do |config|
    # Missing required fields
  end
  AzureFileShares.client.file_shares.list
rescue AzureFileShares::Errors::ConfigurationError => e
  puts "Configuration Error: #{e.message}"
end
```

## Creating Microsoft Entra App Registration

Before using this gem, you need to register an application in Microsoft Entra ID:

1. Sign in to the [Azure portal](https://portal.azure.com)
2. Navigate to **Microsoft Entra ID** > **App registrations** > **New registration**
3. Enter a name for your application
4. Select the appropriate supported account type
5. Click **Register**
6. Once registered, note the **Application (client) ID** and **Directory (tenant) ID**
7. Navigate to **Certificates & secrets** > **Client secrets** > **New client secret**
8. Create a new secret and note the value (you won't be able to see it again)
9. Navigate to **API permissions** and add the following permissions:
   - Microsoft.Storage > user_impersonation
10. Click **Grant admin consent** for your directory

You also need to assign appropriate RBAC roles to the registered application for your storage account:
- **Storage File Data SMB Share Contributor** (for full access)
- **Storage File Data SMB Share Reader** (for read access)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Testing

To run the test suite:

```bash
$ bundle exec rspec
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
