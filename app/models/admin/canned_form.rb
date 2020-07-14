class Admin::CannedForm < ActiveRecord::Base
  belongs_to_account

  attr_accessible :name, :description, :welcome_text, :thankyou_text, :deleted, :version, :fields

  validates_uniqueness_of :name, :scope => :account_id, :case_sensitive => false

  has_many :canned_form_handles, dependent: :destroy, class_name: 'Admin::CannedFormHandle'

  scope :active_forms, conditions: { :deleted => false }

  serialize :message, Hash

  before_update :remove_deleted_fields

  CUSTOM_DB_COLUMNS = {
    varchar_255: { column_name: 'cf_str',      column_limits: 80 },
    text:        { column_name: 'cf_text',     column_limits: 40 },
    tiny_int_1:  { column_name: 'cf_boolean',  column_limits: 40 }
  }.freeze

  CUSTOM_FIELDS_SUPPORTED = [
    :text,
    :paragraph,
    :dropdown,
    :checkbox
  ].freeze

  FORM_OPTIONS = {
    unique_attributes: 'name'
  }.freeze

  acts_as_form field_class: 'Admin::CannedForm::Field', form_id: 'account_form_id'

  DEFAULTS_MESSAGE = {
    welcome_text: 'support.canned_form.welcome_text',
    thankyou_text: 'support.canned_form.thankyou_text'
  }.freeze

  MESSSAGE_ATTRIBUTES = [:welcome_text, :thankyou_text].freeze

  MESSSAGE_ATTRIBUTES.each do |attr_name|
    define_method attr_name.to_s do
      self.message[attr_name.to_s].presence || I18n.t(DEFAULTS_MESSAGE[attr_name])
    end

    define_method "#{attr_name}=" do |value|
      self.message.deep_merge!(attr_name.to_s => value)
    end
  end

  def remove_deleted_fields
    deleted_fields = fields.select { |field| field.deleted == true }
    deleted_fields.each do |field|
      delete_field field.id, false
    end
    true
  end
end

