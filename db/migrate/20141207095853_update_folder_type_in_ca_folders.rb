class UpdateFolderTypeInCaFolders < ActiveRecord::Migration
  shard :all

  def self.up
    default_type = Admin::CannedResponses::Folder::FOLDER_TYPE_KEYS_BY_TOKEN[:default]
    general_type = Admin::CannedResponses::Folder::FOLDER_TYPE_KEYS_BY_TOKEN[:others]

    ShardMapping.find_in_batches(:batch_size => 300) do |shards|
      failed_accounts = []

      shards.each do |shard|
        begin
          Sharding.select_shard_of(shard.account_id) do
            account = Account.find shard.account_id
            account.make_current
            execute("update ca_folders set folder_type=#{default_type} where is_default=true and account_id=#{account.id} and folder_type IS NULL")
            execute("update ca_folders set folder_type=#{general_type} where is_default=false and account_id=#{account.id} and folder_type IS NULL")
          end
        rescue Exception => e
          puts "#{e.message}"
          failed_accounts << shard.account_id
        ensure
          Account.reset_current_account
        end
      end

      puts "Failed_accounts : #{failed_accounts.inspect}"
    end
  end

  def self.down
  end

end
