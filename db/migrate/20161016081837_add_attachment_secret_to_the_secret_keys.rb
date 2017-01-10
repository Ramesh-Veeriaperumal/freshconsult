class AddAttachmentSecretToTheSecretKeys < ActiveRecord::Migration
  shard :all

  def self.up
    failed_accounts = []
    Sharding.run_on_all_shards do
      Account.find_each(:batch_size => 300) do |account|
        account.make_current
        account_additional_settings = account.account_additional_settings
        begin
          if account_additional_settings.secret_keys.blank?
            account_additional_settings.secret_keys = { :attachment_secret => SecureToken.generate }
          else
            account_additional_settings.secret_keys[:attachment_secret] = SecureToken.generate
          end
          account_additional_settings.save!
        rescue => e
          failed_accounts << "#{account.id} => #{e.message}"
        end
      end
    end
    puts failed_accounts.inspect unless failed_accounts.empty?
  end

  def self.down
  end
end