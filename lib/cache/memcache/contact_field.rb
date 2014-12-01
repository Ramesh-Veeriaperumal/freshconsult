module Cache::Memcache::ContactField
  
  include MemcacheKeys

  def contact_fields_from_cache
    key = CONTACT_FORM_FIELDS % {:contact_form_id => self.id}
    MemcacheKeys.fetch(key) { self.fields.all }
  end

  def clear_cache
    key = CONTACT_FORM_FIELDS % { :contact_form_id => self.contact_form_id }
    MemcacheKeys.delete_from_cache key
  end
  
end