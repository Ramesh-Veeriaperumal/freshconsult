module Cache::Memcache::CompanyField
  
  include MemcacheKeys

  def company_fields_from_cache
    key = COMPANY_FORM_FIELDS % {:account_id => self.account_id, :company_form_id => self.id}
    MemcacheKeys.fetch(key) { self.fields.all }
  end

  def clear_company_fields_cache
    key = COMPANY_FORM_FIELDS % {:account_id => current_account.id, 
                                  :company_form_id => current_account.company_form.id}
    MemcacheKeys.delete_from_cache key
  end
  
end