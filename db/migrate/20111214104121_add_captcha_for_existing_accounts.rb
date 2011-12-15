class AddCaptchaForExistingAccounts < ActiveRecord::Migration
  def self.up
     Account.all.each do |account|
      account.features.captcha.create 
    end
  end

  def self.down
    Account.all.each do |account|
      account.features.captcha.destroy
    end
  end
end
