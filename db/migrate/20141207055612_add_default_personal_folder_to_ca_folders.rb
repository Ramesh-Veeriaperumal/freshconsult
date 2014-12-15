class AddDefaultPersonalFolderToCaFolders < ActiveRecord::Migration
  shard :all

  def self.up
    type = 100 #Admin::CannedResponses::Folder::FOLDER_TYPE_KEYS_BY_TOKEN[:personal]    

    Sharding.run_on_all_shards do
      failed_accounts = []

      Account.active_accounts.find_in_batches(:batch_size => 500) do |accounts|
        accounts.each do |account|
          begin
            account.make_current
            execute("insert into ca_folders (name, is_default, account_id, folder_type, created_at, updated_at)
                VALUES('Personal_#{account.id}', true, #{account.id}, #{type}, '#{Time.now.utc.to_s(:db)}', '#{Time.now.utc.to_s(:db)}')")
          rescue => e
            puts "#{e.message}"
            failed_accounts << account.id
          ensure
            Account.reset_current_account
          end
        end
      end

      puts "Failed_accounts : #{failed_accounts.inspect}"  
    end
  end

  def self.down
    Sharding.run_on_all_shards do
      failed_accounts = []

      Account.active_accounts.find_in_batches(:batch_size => 500) do |accounts|
        accounts.each do |account|
          begin
            account.make_current
            if account.canned_response_folders.personal_folder.destroy
              puts "Successfuly removed Personal Folder for ::AccountId : #{account.id}"
            else
              failed_accounts << account.id
            end
          rescue => e
            puts "#{e.message}"
            failed_accounts << account.id
          ensure
            Account.reset_current_account
          end          
        end
      end

      puts "Failed_accounts : #{failed_accounts.inspect}"
    end
  end
end
