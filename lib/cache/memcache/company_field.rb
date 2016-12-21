module Cache::Memcache::CompanyField
  
  include MemcacheKeys

  def company_fields_from_cache
    key = COMPANY_FORM_FIELDS % {:account_id => self.account_id, :company_form_id => self.id}
    MemcacheKeys.fetch(key) { self.fields.all }
  end

  def clear_company_fields_cache
    key = COMPANY_FORM_FIELDS % {:account_id => Account.current.id, 
                                  :company_form_id => Account.current.company_form.id}
    MemcacheKeys.delete_from_cache key
  end

  def clear_cache
    clear_company_fields_cache
  end
  
end