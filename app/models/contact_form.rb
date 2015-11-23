class ContactForm < ActiveRecord::Base

  self.primary_key = :id
  
  include Cache::Memcache::ContactField
  
  serialize :form_options
  belongs_to_account
  attr_protected  :account_id
  acts_as_custom_form :custom_field_class => 'ContactField',
                      :custom_fields_cache_method => :custom_contact_fields

  def contact_fields
    # fetching just once per request, reducing memcache calls
    @contact_fields ||= fetch_contact_fields
  end

  def default_contact_fields
    contact_fields.select{ |cf| cf.default_field? }
  end

  def custom_contact_fields
    contact_fields.select{ |cf| cf.custom_field? }
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

  def custom_non_dropdown_fields
    custom_contact_fields.select { |c| c.field_type != :custom_dropdown }
  end

  def custom_drop_down_fields
    custom_fields.select { |c| c.field_type == :custom_dropdown }
  end

  def custom_dropdown_field_choices
    custom_drop_down_fields.map { |x| [x.api_name.to_sym, x.choices.map { |t| t[:value] }] }.to_h
  end

  def custom_checkbox_fields
    custom_fields.select { |c| c.field_type == :custom_checkbox }
  end

  private

    def fetch_contact_fields
      fields = contact_fields_from_cache
      filter_fields fields, contact_field_conditions
    end

    def filter_fields(field_list, conditions)
      field_list.select{ |field| conditions.fetch(field.name, true) }
    end

    def contact_field_conditions
      { 'time_zone' => Account.current.features?(:multi_timezone), 
        'language' => Account.current.features?(:multi_language) }
    end
    
end
