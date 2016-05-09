class GoogleDomainToRemoteIntegMapping < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    GoogleDomain.all.each do |gd|
      begin
        Integrations::GoogleRemoteAccount.create(:account_id => gd.account_id,
                                                :remote_id => gd.domain)
      rescue => e
        Puts "Error while migrating google domain for the account #{account_id}"
      end
    end
  end

  def down
    Integrations::GoogleRemoteAccount.delete_all
  end

end
