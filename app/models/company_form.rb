class CompanyForm < ActiveRecord::Base

  self.primary_key = :id
  
  include Cache::Memcache::CompanyField
  
  serialize :form_options, Hash # PRE-RAILS: added data type temp, need tovalidate
  belongs_to_account
  attr_protected  :account_id
  acts_as_custom_form :custom_field_class => 'CompanyField',
                        :custom_fields_cache_method => :custom_company_fields

  def company_fields(exclude_encrypted_fields = false)
    # fetching just once per request, reducing memcache calls
    @company_fields ||= fetch_company_fields
    exclude_encrypted_fields ? @company_fields.select{ |cf| !cf.encrypted_field? } : @company_fields
  end

  def default_company_fields
    company_fields.select{ |cf| cf.default_field? }
  end

  def default_widget_fields
    company_fields.select { |cf| cf.default_field? && cf.field_options.present? && cf.field_options.key?('widget_position') }
  end

  def custom_company_fields(exclude_encrypted_fields = false)
    company_fields.select{ |cf| cf.custom_field? && (exclude_encrypted_fields ? !cf.encrypted_field? : true) }
  end

  def encrypted_custom_company_fields
    company_fields.select{ |cf| cf.custom_field? && cf.encrypted_field? }
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

  def tam_default_fields
    default_company_fields.select { |c| Company::TAM_DEFAULT_FIELDS.include?(c.field_type) }
  end

  def default_drop_down_fields(field_type)
    default_company_fields.select { |c| c.field_type == field_type }
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

  def default_health_score_choices
    default_drop_down_fields(Company::DEFAULT_DROPDOWN_FIELD_MAPPINGS[:health_score]).
                first.custom_field_choices.map { |t| t[:value] }
  end

  def default_account_tier_choices
    default_drop_down_fields(Company::DEFAULT_DROPDOWN_FIELD_MAPPINGS[:account_tier]).
                first.custom_field_choices.map { |t| t[:value] }
  end

  def default_industry_choices
    default_drop_down_fields(Company::DEFAULT_DROPDOWN_FIELD_MAPPINGS[:industry]).
                first.custom_field_choices.map { |t| t[:value] }
  end

  def custom_checkbox_fields
    custom_company_fields.select { |c| c.field_type == :custom_checkbox }
  end

  private

    def fetch_company_fields
      fields_from_cache = company_fields_from_cache
      filter_fields(fields_from_cache, company_field_conditions)
    end

    def filter_fields(field_list, conditions)
      field_list.select{ |field| conditions.fetch(field.name, true) }
    end

    def company_field_conditions
      tam_company_fields_feature =  Account.current.tam_default_fields_enabled?
      { 'health_score' =>  tam_company_fields_feature,
        'account_tier' =>  tam_company_fields_feature,
        'industry'     =>  tam_company_fields_feature,
        'renewal_date' =>  tam_company_fields_feature
      }
    end
end