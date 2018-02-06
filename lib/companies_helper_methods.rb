module CompaniesHelperMethods

   def set_validatable_custom_fields
      @company.validatable_custom_fields = { :fields => current_account.company_form.custom_company_fields, 
                                          :error_label => :label }
   end

   def set_required_fields
      @company.required_fields = { :fields => current_account.company_form.agent_required_company_fields, 
                                :error_label => :label }
   end

   def set_validatable_default_fields
      @company.validatable_default_fields = { :fields => current_account.company_form.default_company_fields, 
                                          :error_label => :label }
   end

end