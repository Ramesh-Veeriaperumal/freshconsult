module Export::ExportFields

	def self.allow_field? feature
		return true if feature.nil?
		account = Account.current
		if account.respond_to? feature
			return account.safe_send(feature)
		end
		false
	end
end
