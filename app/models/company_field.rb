class CompanyField < ActiveRecord::Base
  self.primary_key = :id
  self.table_name = 'company_fields'

  include DataVersioning::Model

  serialize :field_options

  belongs_to_account

  validates_uniqueness_of :name, :scope => [:account_id, :company_form_id]

  DEFAULT_FIELD_PROPS = {
    :default_name           => { type: 1, dom_type: :text, label: 'company.name' },
    :default_description    => { type: 2, dom_type: :paragraph, label: 'description', dom_placeholder: 'company.info8' },
    :default_note           => { type: 3, dom_type: :paragraph, label: 'company.notes', dom_placeholder: 'company.info5' },
    :default_domains        => { type: 4, dom_type: :text, label: 'company.info2', dom_placeholder: 'company.info12', bottom_note: 'company.info13' },
    :default_health_score   => { type: 5, dom_type: :dropdown_blank, label: 'company.health_score' },
    :default_account_tier   => { type: 6, dom_type: :dropdown_blank, label: 'company.account_tier' },
    :default_renewal_date   => { type: 7, dom_type: :date, label: 'company.renewal_date' },
    :default_industry       => { type: 8, dom_type: :dropdown_blank, label: 'company.industry' }
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

  VERSION_MEMBER_KEY = 'COMPANY_FIELD'.freeze

  inherits_custom_field :form_class => 'CompanyForm', :form_id => :company_form_id,
                        :custom_form_method => :default_company_form,
                        :field_data_class => 'CompanyFieldData',
                        :field_choices_class => 'CompanyFieldChoice'

  # after_commit :clear_company_fields_cache # Clearing cache in CompanyFieldsController#update action
  # Can't clear cache on every CompanyField or CompanyFieldChoices save

  def default_company_form dummy_company_form_id
    (Account.current || account).company_form
  end

  def label
    self.default_field? ? I18n.t("#{self.default_field_label}") : read_attribute(:label)
  end

  def admin_choices
    case field_type
      when :"custom_dropdown" then
        custom_field_choices.collect { |choice| {:id => choice.id, :name => choice.value, :value => choice.value, 
          :position => choice.position, :_destroy => choice._destroy} }
      when :"custom_survey_radio" then
        custom_field_choices.collect { |choice| {:id => choice.id, :name => choice.value, :value => choice.value, 
          :face_value => choice.face_value, :position => choice.position, :_destroy => choice._destroy} }
      when :"default_time_zone" then
        self.class::TIME_ZONE_ADMIN_CHOICES 
      when :"default_language" then
        self.class::LANGUAGE_ADMIN_CHOICES
      when :default_account_tier then
          custom_field_choices.collect { |choice| {:id => choice.id, :name => choice.value, :value => choice.value, 
              :position => choice.position, :_destroy => choice._destroy} }
      when :default_industry then
          custom_field_choices.collect { |choice| {:id => choice.id, :name => choice.value, :value => choice.value, 
              :position => choice.position, :_destroy => choice._destroy} }
      when :default_health_score then
          custom_field_choices.collect { |choice| {:id => choice.id, :name => choice.value, :value => choice.value, 
              :position => choice.position, :_destroy => choice._destroy} }
      else
           []
    end
  end
  alias_method :choices, :admin_choices

  def ui_choices
    case field_type
      when :"custom_dropdown" then
        @choices ||= custom_field_choices.collect { |c| [CGI.unescapeHTML(c.value), c.value.to_sym] }
      when :"custom_survey_radio" then
        @choices ||= custom_field_choices.collect { |c| [CGI.unescapeHTML(c.value), c.face_value.to_sym] }
      when :'default_time_zone' then
        self.class::TIME_ZONE_UI_CHOICES
      when :'default_language' then
        self.class::LANGUAGE_UI_CHOICES
      when :default_account_tier then
        @choices ||= custom_field_choices.collect { |c| [CGI.unescapeHTML(c.value), c.value.to_sym] }
      when :default_industry then
        @choices ||= custom_field_choices.collect { |c| [CGI.unescapeHTML(c.value), c.value.to_sym] }
      when :default_health_score then
        @choices ||= custom_field_choices.collect { |c| [CGI.unescapeHTML(c.value), c.value.to_sym] }
      else
        []
     end
  end
end
