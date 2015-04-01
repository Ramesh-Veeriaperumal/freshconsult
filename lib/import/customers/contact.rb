class Import::Customers::Contact < Import::Customers::Base

	def initialize(params={})
		super params
	end

	def default_validations
		item_param = @params_hash[:"#{@type}"]
		item_param[:name] = "" if item_param[:name].nil? && item_param[:email].blank?
		item_param[:client_manager] = item_param[:client_manager].to_s.strip.downcase == "yes" ? "true" : nil

		company_name = item_param[:company_name].to_s.strip
		item_param[:company_id] = current_account.companies.find_or_create_by_name(company_name).id unless company_name.blank?

		load_item item_param
	end

	def create_imported_contact
		@params_hash[:user][:helpdesk_agent] = false #To make already deleted user active
		@item.signup!(@params_hash)
	end

	private

	def load_item item_param
		search_options = {:email => item_param[:email], :twitter_id => item_param[:twitter_id]}
		@item = current_account.all_users.find_by_an_unique_id(search_options)
		@params_hash[:user][:deleted] = false unless @item.nil?
	end
end