module Cache::Memcache::ContactField
  
  include MemcacheKeys

  def contact_fields_from_cache
    key = CONTACT_FORM_FIELDS % {:account_id => self.account_id, :contact_form_id => self.id}
    MemcacheKeys.fetch(key) { self.fields.all }
  end

  def clear_contact_fields_cache
    key = CONTACT_FORM_FIELDS % {:account_id => current_account.id, 
                                  :contact_form_id => current_account.contact_form.id}
    MemcacheKeys.delete_from_cache key
  end
  
end