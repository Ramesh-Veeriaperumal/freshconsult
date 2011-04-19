class AddDefaultSsoForAllAccounts < ActiveRecord::Migration
  def self.up
	Account.all.each do |account|
		account.shared_secret = Digest::MD5.hexdigest(Helpdesk::SHARED_SECRET + account.full_domain + account.created_at.to_s).downcase
		account.sso_options = HashWithIndifferentAccess.new({:login_url => "",:logout_url => ""})
		account.save!
    end
  end

  def self.down
	Account.all.each do |account|
		account.shared_secret = nil
		account.sso_options = nil
		account.save!
    end
  end
end
