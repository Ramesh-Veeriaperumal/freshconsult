class InstalledApplicationValidation < FilterValidation

	attr_accessor :name
	validates :name, data_type: { rules: String, allow_nil: false }

end