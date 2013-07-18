class Subscription::EnsureReseller
	require 'base64'
	extend Resque::AroundPerform
	@queue = "ensure_reseller"
	
	def self.perform(args)
		account = Account.current
		token = SubscriptionAffiliate.check_affiliate_in_metrics?(account)
		secret_key = Digest::SHA1.hexdigest(AppConfig['partner']['secret_key']+token["STAMP"])
		decrypted_value = Encryptor.decrypt(Base64.decode64(token["FDRES"]), :key => secret_key)
		SubscriptionAffiliate.attach_affiliate(account,decrypted_value)
		
	end
end