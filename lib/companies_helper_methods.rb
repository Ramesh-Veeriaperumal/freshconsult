module CompaniesHelperMethods

   def set_validatable_custom_fields
      @company.validatable_custom_fields = { :fields => current_account.company_form.custom_company_fields, 
                                          :error_label => :label }
   end

   def set_required_fields
      @company.required_fields = { :fields => current_account.company_form.agent_required_company_fields, 
                                :error_label => :label }
   end

   def scoper
      current_account.companies
   end

   def build_item
      @company = scoper.new
      @company.attributes = params[:company]
   end

end