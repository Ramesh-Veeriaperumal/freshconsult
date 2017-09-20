class CompanyForm < ActiveRecord::Base

  self.primary_key = :id
  
  include Cache::Memcache::CompanyField
  
  serialize :form_options
  belongs_to_account
  attr_protected  :account_id
  acts_as_custom_form :custom_field_class => 'CompanyField',
                        :custom_fields_cache_method => :custom_company_fields

  def company_fields
    # fetching just once per request, reducing memcache calls
    @company_fields ||= company_fields_from_cache
  end

  def default_company_fields
    company_fields.select{ |cf| cf.default_field? }
  end

  def default_widget_fields
    company_fields.select { |cf| cf.default_field? && cf.field_options.present? && cf.field_options.key?('widget_position') }
  end

  def custom_company_fields
    company_fields.select{ |cf| cf.custom_field? }
  end

  def agent_required_company_fields
    company_fields.select{ |cf| cf.required_for_agent }
  end

  def custom_non_dropdown_fields
    custom_company_fields.select { |c| c.field_type != :custom_dropdown }
  end

  def custom_drop_down_fields
    custom_company_fields.select { |c| c.field_type == :custom_dropdown }
  end

  def custom_dropdown_field_choices
    custom_drop_down_fields.map { |x| [x.name, x.choices.map { |t| t[:value] }] }.to_h
  end

  def custom_fields_in_widget
    company_fields.select { |cf| cf.custom_field? && cf.field_options.present? && cf.field_options.key?('widget_position') }
  end

  def custom_non_dropdown_widget_fields
    custom_company_fields.select { |c| c.field_type != :custom_dropdown && c.field_options.present? && c.field_options.key?('widget_position') }
  end

  def custom_drop_down_widget_fields
    custom_company_fields.select { |c| c.field_type == :custom_dropdown && c.field_options.present? && c.field_options.key?('widget_position') }
  end

  def custom_dropdown_widget_field_choices
    custom_drop_down_widget_fields.map { |x| [x.name, x.choices.map { |t| t[:value] }] }.to_h
  end

  def custom_checkbox_fields
    custom_company_fields.select { |c| c.field_type == :custom_checkbox }
  end

end