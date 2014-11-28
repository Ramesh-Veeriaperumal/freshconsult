class ContactForm < ActiveRecord::Base

  include Cache::Memcache::ContactField
  
  serialize :form_options
  belongs_to_account
  attr_protected  :account_id
  acts_as_custom_form :custom_field_class => 'ContactField'

  def contact_fields
    # fetching just once per request, reducing memcache calls
    @contact_fields ||= fetch_contact_fields
  end

  def default_contact_fields
    contact_fields.select{ |cf| cf.column_name == 'default' }
  end

  def custom_contact_fields
    contact_fields.select{ |cf| cf.column_name != 'default' }
  end

  def customer_visible_contact_fields
    contact_fields.select{ |cf| cf.visible_in_portal }
  end

  def customer_signup_contact_fields
    contact_fields.select{ |cf| cf.editable_in_signup }
  end

  def customer_signup_invisible_contact_fields
    contact_fields.reject{ |cf| cf.editable_in_signup }
  end

  def customer_noneditable_contact_fields
    contact_fields.reject{ |cf| cf.editable_in_portal }
  end

  def customer_required_contact_fields
    contact_fields.select{ |cf| cf.required_in_portal }
  end

  def agent_required_contact_fields
    contact_fields.select{ |cf| cf.required_for_agent }
  end

  def contact_custom_fields
    contact_fields.select{ |cf| cf.custom_field? }
  end

  private

    def fetch_contact_fields
      fields = contact_fields_from_cache
      filter_fields fields, contact_field_conditions
    end

    def filter_fields(f_list, conditions)
      to_ret = []

      f_list.each { |field| to_ret.push(field) if conditions.fetch(field.name, true) }
      to_ret
    end

    def contact_field_conditions
      { 'time_zone' => account.features?(:multi_timezone), 
        'language' => account.features?(:multi_language) }
    end
    
end
