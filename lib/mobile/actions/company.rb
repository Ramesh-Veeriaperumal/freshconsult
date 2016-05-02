module Mobile::Actions::Company
	JSON_OPTIONS = {
		:only => [:id, :name]
	}
  CUSTOMER_JSON_OPTIONS = { # will be deprecated once the mobile apps are updated
    :root => 'customer',
    :only => [:id, :name]
  }
	def to_mob_json_search
		as_json(JSON_OPTIONS).merge(as_json(CUSTOMER_JSON_OPTIONS))
	end

	def company_custom_fields
    	Account.current.company_form.custom_company_fields
    end

end