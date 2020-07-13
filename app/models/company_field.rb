class CompanyField < ActiveRecord::Base
  self.primary_key = :id
  self.table_name = 'company_fields'

  include DataVersioning::Model
  include CompanyFieldsConstants
  include ContactCompanyFields::PublisherMethods

serialize :field_options

  belongs_to_account

  validates_uniqueness_of :name, :scope => [:account_id, :company_form_id]

  before_save  :construct_model_changes, on: :update
  after_save   :prepare_to_update_segment_filter
  after_commit :update_segment_filter, on: :update

  before_destroy :save_deleted_company_field_info

  concerned_with :presenter

  publishable

  DEFAULT_FIELD_PROPS = {
    :default_name           => { type: 1, dom_type: :text,
                                 label: 'company.name'
                               },
    :default_description    => { type: 2, dom_type: :paragraph, 
                                 label: 'description',
                                 dom_placeholder: 'company.info8'
                               },
    :default_note           => { type: 3, dom_type: :paragraph,
                                 label: 'company.notes',
                                 dom_placeholder: 'company.info5'
                               },
    :default_domains        => { type: 4, dom_type: :text,
                                 label: 'company.info2',
                                 dom_placeholder: 'company.info12',
                                 bottom_note: 'company.info13'
                               },
    :default_health_score   => { type: 5, dom_type: :dropdown_blank,
                                 label: 'company.health_score'
                               },
    :default_account_tier   => { type: 6, dom_type: :dropdown_blank,
                                 label: 'company.account_tier'
                               },
    :default_renewal_date   => { type: 7, dom_type: :date,
                                 label: 'company.renewal_date'
                               },
    :default_industry       => { type: 8, dom_type: :dropdown_blank,
                                 label: 'company.industry'
                               }
  }

  CUSTOM_FIELDS_SUPPORTED = [ :custom_text, :custom_paragraph, :custom_checkbox, :custom_number,
                              :custom_dropdown, :custom_phone_number, :custom_url, :custom_date, :encrypted_text ]

  DB_COLUMNS = {
    :text         => { :column_name => "cf_text",     :column_limits => 10 },
    :varchar_255  => { :column_name => "cf_str",      :column_limits => 70 },
    :integer_11   => { :column_name => "cf_int",      :column_limits => 20 },
    :date_time    => { :column_name => "cf_date",     :column_limits => 10 },
    :tiny_int_1   => { :column_name => "cf_boolean",  :column_limits => 10 }
  }

  VERSION_MEMBER_KEY = 'COMPANY_FIELD_LIST'.freeze

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

  def self.create_company_field(field_data, account)
    field_name = field_data.delete(:name)
    column_name = field_data.delete(:column_name)
    deleted = field_data.delete(:deleted)
    if FIELDS_WITH_CHOICES.include?(field_name)
      field_data[:custom_field_choices_attributes] = TAM_FIELDS_DATA["#{field_name}_data"]
    end
    company_field = CompanyField.new(field_data)

    # The following are attribute protected.
    company_field.column_name = column_name
    company_field.name = field_name
    company_field.deleted = deleted
    company_field.company_form_id = account.company_form.id
    company_field.save
  end

  def admin_choices_field_hash(choice)
    choice_key = TAM_FIELDS_EN_KEYS_MAPPING.key(choice.value)
    {:id => choice.id,
     :name => choice_key ? I18n.t(choice_key) : choice.value,
     :value => choice_key ? I18n.t(choice_key) : choice.value,
     :position => choice.position,
     :_destroy => choice._destroy}
  end

  def ui_choices_field_hash(choice)
    choice_key = TAM_FIELDS_EN_KEYS_MAPPING.key(choice.value)
    [CGI.unescapeHTML(choice_key ? I18n.t(choice_key) : choice.value),
     (choice_key ? I18n.t(choice_key) : choice.value).to_sym]
  end

  def admin_choices
    case field_type
      when :default_account_tier then
        custom_field_choices.collect { |choice|
          admin_choices_field_hash(choice)
        }
      when :default_industry then
        custom_field_choices.collect { |choice|
          admin_choices_field_hash(choice)
        }
      when :default_health_score then
        custom_field_choices.collect { |choice|
          admin_choices_field_hash(choice)
        }
      else
          super
    end
  end
  alias_method :choices, :admin_choices

  def ui_choices
    case field_type
      when :default_account_tier then
        @choices ||= custom_field_choices.collect { |choice|
          ui_choices_field_hash(choice)
        }
      when :default_industry then
        @choices ||= custom_field_choices.collect { |choice|
          ui_choices_field_hash(choice)
        }
      when :default_health_score then
        @choices ||= custom_field_choices.collect { |choice|
          ui_choices_field_hash(choice)
        }
      else
        super
     end
  end

  def prepare_to_update_segment_filter
    @marked_as_deleted = deleted_changed? && deleted?
  end

  def update_segment_filter
    if @marked_as_deleted
      UpdateSegmentFilter.perform_async({ custom_field: attributes, type: self.class.name })
    end
  end

  def save_deleted_company_field_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end

  def custom_checkbox_field?
    field_type.to_sym == :custom_checkbox
  end
end
