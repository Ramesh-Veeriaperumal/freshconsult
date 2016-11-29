class AddAttachmentSecretToTheSecretKeys < ActiveRecord::Migration
  shard :all

  def self.up
    failed_accounts = []
    Sharding.run_on_all_shards do
      AccountAdditionalSettings.find_each(:batch_size => 300) do |account_additional_settings|
        account_additional_settings.account.make_current
        begin
          if account_additional_settings.secret_keys.nil?
            account_additional_settings.secret_keys = { :attachment_secret => SecureToken.generate }
          else
            account_additional_settings.secret_keys[:attachment_secret] = SecureToken.generate
          end
          account_additional_settings.save!
        rescue => e
          failed_accounts << "#{account_additional_settings.account_id} => #{e.message}"
        end
      end
    end
    puts failed_accounts.inspect unless failed_accounts.empty?
  end

  def self.down
  end
end