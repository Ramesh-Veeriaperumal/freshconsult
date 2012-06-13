class AddFacebookFeature < ActiveRecord::Migration
def self.up
  	Account.all.each do |account|
      account.features.facebook_signin.create 
    end
end

def self.down
  	Account.all.each do |account|
  		account.features.facebook_signin.destroy 
	end
end
end
