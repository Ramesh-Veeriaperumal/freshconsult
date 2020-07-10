class ContactField < ActiveRecord::Base
  self.primary_key = :id

  include DataVersioning::Model
  include ContactCompanyFields::PublisherMethods

  serialize :field_options, Hash

  belongs_to_account

  before_save   :set_portal_edit, :construct_model_changes
  before_create :populate_label
  after_save    :prepare_to_update_segment_filter
  after_commit :toggle_multiple_companies_feature, :update_segment_filter, on: :update

  before_destroy :save_deleted_contact_field_info

  validates_uniqueness_of :name, :scope => [:account_id, :contact_form_id]

  concerned_with :presenter

  publishable

  scope :customer_visible, -> { where(visible_in_portal: true) }
  scope :customer_editable, -> { where(editable_in_portal: true) }

  DEFAULT_FIELD_PROPS = {
    :default_name                 => { :type => 1,  :dom_type => :text, :label => 'user.full_name' },
    :default_job_title            => { :type => 2,  :dom_type => :text, :label => 'user.title' },
    :default_email                => { :type => 3,  :dom_type => :email, :label => 'user.email' },
    :default_phone                => { :type => 4,  :dom_type => :phone_number, :label => 'user.work_phone' },
    :default_mobile               => { :type => 5,  :dom_type => :phone_number, :label => 'user.mobile_phone' },
    :default_twitter_id           => { :type => 6,  :dom_type => :text, :label => 'user.twitter_id' },
    :default_company_name         => { :type => 7,  :dom_type => :text, :label => 'user.company' },
    :default_client_manager       => { :type => 8,  :dom_type => :checkbox, :label => 'contacts.role.info' },
    :default_address              => { :type => 9,  :dom_type => :paragraph, :label => 'user.address' },
    :default_time_zone            => { :type => 10, :dom_type => :dropdown, :label => 'account.time_zone' },
    :default_language             => { :type => 11, :dom_type => :dropdown, :label => 'account.language' },
    :default_tag_names            => { :type => 12, :dom_type => :text, :label => 'tag.title' },
    :default_description          => { :type => 13, :dom_type => :paragraph, :label => 'user.back_info',
                                  :dom_placeholder => 'contacts.info_example' },
    :default_unique_external_id   => { :type => 14,  :dom_type => :text, :label => 'user.unique_external_id' },
    default_twitter_profile_status: { type: 15, dom_type: :text, label: 'user.twitter_profile_status' },
    default_twitter_followers_count: { type: 16, dom_type: :number, label: 'user.twitter_followers_count' }
  }

  CUSTOM_FIELDS_SUPPORTED = [ :custom_text, :custom_paragraph, :custom_checkbox, :custom_number,
                              :custom_dropdown, :custom_phone_number, :custom_url, :custom_date, :encrypted_text ]

  DB_COLUMNS = {
    :varchar_255  => { :column_name => "cf_str",      :column_limits => 70 },
    :integer_11   => { :column_name => "cf_int",      :column_limits => 20 },
    :date_time    => { :column_name => "cf_date",     :column_limits => 10 },
    :tiny_int_1   => { :column_name => "cf_boolean",  :column_limits => 10 },
    :text         => { :column_name => "cf_text",     :column_limits => 10 }
  }

  VERSION_MEMBER_KEY = 'CONTACT_FIELD_LIST'.freeze

  attr_accessor :multiple_companies_contact
  inherits_custom_field :form_class => 'ContactForm', :form_id => :contact_form_id,
                        :custom_form_method => :default_contact_form,
                        :field_data_class => 'ContactFieldData',
                        :field_choices_class => 'ContactFieldChoice'

  # after_commit :clear_contact_fields_cache # Clearing cache in ContactFieldsController#update action
  # Can't clear cache on every ContactField or ContactFieldChoices save

  def default_contact_form dummy_contact_form_id
    (Account.current || account).contact_form
  end

  def set_portal_edit
    self.editable_in_portal = false unless visible_in_portal
    self
  end

  def populate_label
    self.label = name.titleize if label.blank?
    self.label_in_portal = label if label_in_portal.blank?
  end

  def toggle_multiple_companies_feature
    if self.name == "company_name" && self.multiple_companies_contact
      if Account.current.multiple_user_companies_enabled?
        Account.current.revoke_feature(:multiple_user_companies)
        Users::RemoveSecondaryCompanies.perform_async
      else
        Account.current.add_feature(:multiple_user_companies)
      end
    end
  end

  def label
    self.default_field? ? I18n.t("#{self.default_field_label}") : read_attribute(:label)
  end

  def label_in_portal
    self.default_field? ? I18n.t("#{self.default_field_label}") : read_attribute(:label_in_portal)
  end

  def prepare_to_update_segment_filter
    @marked_as_deleted = deleted_changed? && deleted?
  end

  def update_segment_filter
    if @marked_as_deleted
      UpdateSegmentFilter.perform_async({ custom_field: attributes, type: self.class.name })
    end
  end

  def save_deleted_contact_field_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end

  def custom_checkbox_field?
    field_type.to_sym == :custom_checkbox
  end

  def twitter_field?
    name == 'twitter_profile_status' || name == 'twitter_followers_count'
  end
end
