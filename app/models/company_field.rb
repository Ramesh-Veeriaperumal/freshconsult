class CompanyField < ActiveRecord::Base

  self.primary_key = :id
  self.table_name= "company_fields"

  serialize :field_options

  belongs_to_account

  validates_uniqueness_of :name, :scope => [:account_id, :company_form_id]

  DEFAULT_FIELD_PROPS = {
    :default_name           => { :type => 1, :dom_type => :text, :label => 'company.name' },
    :default_description    => { :type => 2, :dom_type => :paragraph, :label => 'description', :dom_placeholder =>  'company.info8' },
    :default_note           => { :type => 3, :dom_type => :paragraph, :label => 'company.notes', :dom_placeholder => 'company.info5' },
    :default_domains        => { :type => 4, :dom_type => :text, :label => 'company.info2', :bottom_note => 'company.info9' }
  }

  CUSTOM_FIELDS_SUPPORTED = [ :custom_text, :custom_paragraph, :custom_checkbox, :custom_number,
                              :custom_dropdown, :custom_phone_number, :custom_url, :custom_date ]

  DB_COLUMNS = {
    :text         => { :column_name => "cf_text",     :column_limits => 10 }, 
    :varchar_255  => { :column_name => "cf_str",      :column_limits => 70 }, 
    :integer_11   => { :column_name => "cf_int",      :column_limits => 20 }, 
    :date_time    => { :column_name => "cf_date",     :column_limits => 10 }, 
    :tiny_int_1   => { :column_name => "cf_boolean",  :column_limits => 10 }
  }

  inherits_custom_field :form_class => 'CompanyForm', :form_id => :company_form_id,
                        :custom_form_method => :default_company_form,
                        :field_data_class => 'CompanyFieldData',
                        :field_choices_class => 'CompanyFieldChoice'

  # after_commit :clear_company_fields_cache # Clearing cache in CompanyFieldsController#update action
  # Can't clear cache on every CompanyField or CompanyFieldChoices save

  def default_company_form
    (Account.current || account).company_form
  end

  def label
    self.default_field? ? I18n.t("#{self.default_field_label}") : read_attribute(:label)
  end
end