class Helpdesk::SchemaLessNote < ActiveRecord::Base

  include RabbitMq::Publisher
  # Including this because we are doing business hour calculation in rabbitmq for reports
  include BusinessHoursCalculation
  include Helpdesk::EmailFailureMethods

  self.table_name =  "helpdesk_schema_less_notes"
  self.primary_key = :id

  PRESENTER_FIELDS_MAPPING = { 'int_nc01' => 'category', 'int_nc02' => 'response_time_in_seconds', 'int_nc03' => 'response_time_by_bhrs',
                               'long_nc01' => 'email_config_id', 'string_nc01' => 'subject' }.freeze
  
  alias_attribute :header_info, :text_nc01
  alias_attribute :category, :int_nc01
  alias_attribute :response_time_in_seconds, :int_nc02
  alias_attribute :response_time_by_bhrs, :int_nc03
  alias_attribute :email_config_id, :long_nc01
  alias_attribute :subject, :string_nc01
  alias_attribute :note_properties, :text_nc02

  alias_attribute :sentiment, :int_nc04
  
  serialize :to_emails, Array
  serialize :cc_emails, [Array, Hash]
  serialize :bcc_emails, Array
  serialize :header_info, String
  serialize :text_nc02, Hash

  belongs_to_account  
  belongs_to :note, :class_name =>'Helpdesk::Note'

  attr_protected :note_id, :account_id
  validate :cc_and_bcc_emails_count

  before_save :construct_model_changes

  publishable on: [:update], exchange_model: :note, exchange_action: :update

  def self.resp_time_column
    :int_nc02
  end

  def self.resp_time_by_bhrs_column
    :int_nc03
  end

  def self.category_column
    :int_nc01
  end

  def import_id
    note_properties[:import_id]
  end

  def import_id=(import_id)
    note_properties[:import_id] = import_id
  end
  
  def last_modified_user_id
    note_properties[:last_modified_user_id] if note_properties.is_a?(Hash)
  end

  def last_modified_user_id=(user_id)
    note_properties[:last_modified_user_id] = user_id.to_s
  end

  def quoted_parsing_done=(quoted_parse_val)
    note_properties[:quoted_parsing_done] = quoted_parse_val
  end

  def quoted_parsing_done
    note_properties[:quoted_parsing_done]
  end

  def last_modified_timestamp
    note_properties[:last_modified_timestamp].to_datetime.in_time_zone(Time.zone) if note_properties.is_a?(Hash) && note_properties[:last_modified_timestamp].present?
  end

  def last_modified_timestamp=(curr_time)
    note_properties[:last_modified_timestamp] = curr_time.to_s
  end

  def on_state_time
    note_properties[:on_state_time]
  end

  def on_state_time=(value)
    note_properties[:on_state_time] = value
  end

  def response_violated
    note_properties[:response_violated] if note_properties.is_a?(Hash)
  end

  def response_violated=(value)
    note_properties[:response_violated] = value
  end

  def cc_emails
    emails = read_attribute(:cc_emails)
    if (emails.is_a? Array) || (emails.is_a? String)
        emails
    else
        emails[:cc_emails] if emails.present?
    end    
  end

  def cc_emails=(emails)
    if emails.is_a? Array
        emails = { :cc_emails => emails, :dropped_cc_emails => []}
    end
    write_attribute(:cc_emails, emails)
  end

  def cc_emails_hash
    emails = read_attribute(:cc_emails)
    if emails.is_a?(Array) || emails.is_a?(String)  || emails.blank?  
      {:cc_emails => emails, :dropped_cc_emails => []}
    else
      emails
    end
  end

  def cc_and_bcc_emails_count
    if ((!cc_emails.blank? && cc_emails.is_a?(Array) && cc_emails.count >= TicketConstants::MAX_EMAIL_COUNT) || 
        (!bcc_emails.blank? && bcc_emails.is_a?(Array) && bcc_emails.count >= TicketConstants::MAX_EMAIL_COUNT) ||
        (!to_emails.blank? && to_emails.is_a?(Array) && to_emails.count >= TicketConstants::MAX_EMAIL_COUNT))
      self.errors.add(:base,"You have exceeded the limit of #{TicketConstants::MAX_EMAIL_COUNT} emails")
      return false
    end
    return true
  end

  def thank_you_note
    note_properties[:thank_you_note]
  end

  def thank_you_note=(val)
    note_properties[:thank_you_note] = val
  end

  def override_exchange_model(_action)
    changes = @schema_less_note_changes.slice(*PRESENTER_FIELDS_MAPPING.keys)
    changes.keys.each do |key|
      changes[PRESENTER_FIELDS_MAPPING[key]] = changes.delete key if PRESENTER_FIELDS_MAPPING.key?(key)
    end
    note.model_changes = changes if changes.present?
  end

  def construct_model_changes
    @schema_less_note_changes = changes.clone
  end

  private

  def email_failures
    note_properties
  end
  
end
