class ContactField < ActiveRecord::Base

  self.primary_key = :id
  
  serialize :field_options

  belongs_to_account

  before_save   :set_portal_edit
  before_create :populate_label

  validates_uniqueness_of :name, :scope => [:account_id, :contact_form_id]

  scope :customer_visible, :conditions => { :visible_in_portal => true }
  scope :customer_editable, :conditions => { :editable_in_portal => true }
  
  DEFAULT_FIELD_PROPS = {
    :default_name           => { :type => 1,  :dom_type => :text, :label => 'user.full_name' },
    :default_job_title      => { :type => 2,  :dom_type => :text, :label => 'user.title' },
    :default_email          => { :type => 3,  :dom_type => :email, :label => 'user.email' },
    :default_phone          => { :type => 4,  :dom_type => :phone_number, :label => 'user.work_phone' },
    :default_mobile         => { :type => 5,  :dom_type => :phone_number, :label => 'user.mobile_phone' },
    :default_twitter_id     => { :type => 6,  :dom_type => :text, :label => 'user.twitter_id' },
    :default_company_name   => { :type => 7,  :dom_type => :text, :label => 'user.company' },
    :default_client_manager => { :type => 8,  :dom_type => :checkbox, :label => 'contacts.role.info' },
    :default_address        => { :type => 9,  :dom_type => :paragraph, :label => 'user.address' },
    :default_time_zone      => { :type => 10, :dom_type => :dropdown, :label => 'account.time_zone' },
    :default_language       => { :type => 11, :dom_type => :dropdown, :label => 'account.language' },
    :default_tag_names      => { :type => 12, :dom_type => :text, :label => 'tag.title' },
    :default_description    => { :type => 13, :dom_type => :paragraph, :label => 'user.back_info',
                                 :dom_placeholder => 'contacts.info_example' }
  }

  CUSTOM_FIELDS_SUPPORTED = [ :custom_text, :custom_paragraph, :custom_checkbox, :custom_number,
                              :custom_dropdown, :custom_phone_number, :custom_url, :custom_date ]

  DB_COLUMNS = {
    :varchar_255  => { :column_name => "cf_str",      :column_limits => 70 }, 
    :integer_11   => { :column_name => "cf_int",      :column_limits => 20 }, 
    :date_time    => { :column_name => "cf_date",     :column_limits => 10 }, 
    :tiny_int_1   => { :column_name => "cf_boolean",  :column_limits => 10 },
    :text         => { :column_name => "cf_text",     :column_limits => 10 }
  }

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

  def label
    self.default_field? ? I18n.t("#{self.default_field_label}") : read_attribute(:label)
  end

  def label_in_portal
    self.default_field? ? I18n.t("#{self.default_field_label}") : read_attribute(:label_in_portal)
  end

end
