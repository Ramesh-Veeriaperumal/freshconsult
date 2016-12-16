class Import::Customers::Company < Import::Customers::Base

	def initialize(params={})
		super params
	end

	def default_validations
		item_param = @params_hash[:"#{@type}"]
		item_param[:name].blank? ? return : load_item	
	end

	def create_imported_company
		@item.attributes = @params_hash[:company]
		@item.save
	end

	private

	def load_item 
		decode_params
		@item = current_account.companies.find_by_name(@params_hash[:company][:name])
	end

	def decode_params
		@params_hash[:company][:name].to_s.strip!
		@params_hash[:company][:name].gsub!(/&amp;/, "&")
	end
end