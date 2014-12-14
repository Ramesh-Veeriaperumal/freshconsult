class UpdatePersonalFolderIdInAdminUserAccesses < ActiveRecord::Migration
  shard :all

  def self.up
    ShardMapping.find_in_batches(:batch_size => 300) do |shards|
      failed_accounts = []

      shards.each do |shard|
        begin
          Sharding.select_shard_of(shard.account_id) do
            account = Account.find shard.account_id
            account.make_current
            pfolder_id   = account.canned_response_folders.personal_folder.first.id
            response_ids = account.canned_responses.find(:all, :joins => :accessible,
                                                         :conditions => { :admin_user_accesses => { :accessible_type => 'Admin::CannedResponses::Response', :visibility => 3 }},
                                                         :select     => "admin_canned_responses.id").collect(&:id)
            execute("update admin_canned_responses set folder_id=#{pfolder_id} where id in (#{response_ids.join(',')})") unless response_ids.blank?
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
