class Import::Customers::Company < Import::Customers::Base

	def initialize(params={})
		super params
	end

	def default_validations
		item_param = @params_hash[:"#{@type}"]
		item_param[:name].blank? ? return : load_item(item_param)	
	end

	def create_imported_company
		@item.attributes = @params_hash[:company]
		@item.save
	end

	private

	def load_item item_param
		company_name = item_param[:name].to_s.strip
		@item = current_account.companies.find_by_name(company_name)
	end
end