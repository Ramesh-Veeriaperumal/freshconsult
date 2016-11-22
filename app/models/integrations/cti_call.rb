class Integrations::CtiCall < ActiveRecord::Base
  include RabbitMq::Publisher
  include Integrations::CtiHelper
  self.table_name =  :cti_calls

  NONE = 0
  VIEWING = 1
  SYS_CONVERTED = 2
  IGNORED = 3
  AGENT_CONVERTED = 4

  STATUSES = {
    NONE => "none",
    VIEWING => "viewing",
    SYS_CONVERTED => "system converted",
    IGNORED => "ignored",
    AGENT_CONVERTED => "agent converted"
  }
  serialize :options, Hash
  belongs_to_account

  belongs_to :recordable, :polymorphic => true
  belongs_to :responder, :class_name => 'User', :conditions => { :helpdesk_agent => true, :deleted => false }
  belongs_to :requester, :class_name => 'User'
  belongs_to :installed_application, :class_name => Integrations::InstalledApplication
  alias_attribute :call_reference_id, :call_sid

  validate :ticket_exists?, if: -> { options[:ticket_id].present? }
  validate :validate_requester, if: -> { requester_id.nil? }
  validate :validate_responder, if: -> { responder_id.nil? }
  validates :requester, presence: true, if: -> { requester_id.present? }
  validates :responder, presence: true, if: -> { responder_id.present? }
  before_create :populate_installed_app
  before_create :create_new_ticket, if: -> { options[:new_ticket] }

  def self.last_agent_call(call)
     where("responder_id = ? and id != ? and created_at < ?", call.responder_id, call.id, call.created_at).order(:created_at).last
  end

  def status_name
    STATUSES[self.status]
  end

  def populate_installed_app
    self.installed_application_id = Account.current.cti_installed_app_from_cache.id
  end

  def cti_allowed?
    account.features?(:cti)
  end

  def create_new_ticket
    self.recordable = cti_create_ticket(self)
    self.status = Integrations::CtiCall::SYS_CONVERTED
    self.options[:ticket_id] = self.recordable.display_id
  end

  def ticket_exists?
      errors[:ticket_id] << :"can't be blank" unless Account.current.tickets.exists?(display_id: options[:ticket_id])
  end


  def validate_requester
    user = find_user_for_params(options[:requester_unique_external_id], options[:requester_email], options[:requester_phone])
    if user.nil?
      user = Account.current.contacts.new
      user_hash = {
        user: { 
          phone: options[:requester_phone],
          unique_external_id: options[:requester_unique_external_id],
          email: options[:requester_email]
        }
      }
      user_hash[:user][:name] = options[:requester_unique_external_id] || options[:requester_phone] unless options[:requester_email].present?
      saved = user.signup!(user_hash)
      unless saved
        errors[:requester] << I18n.t('integrations.cti_call.contact_creation_failed')
        Rails.logger.error "Error creating the contact. #{user.errors.full_messages.inspect}"
        return
      end
    end
    self.requester_id = user.id
  end

  def validate_responder
    user = find_agent_for_params(options[:responder_unique_external_id], options[:responder_email], options[:responder_phone])
    if user.nil?
      errors[:responder] << I18n.t('integrations.cti_call.invalid_responder_detail')
    else
      self.responder_id = user.id
    end

  end

  def find_user_for_params(unique_external_id, email, phone)
    user = nil
    user = Account.current.users.where(:unique_external_id => unique_external_id).first if unique_external_id.present?
    user = Account.current.user_emails.user_for_email(email) if user.nil? && email.present?
    user = find_user_by_phone(phone) if user.nil? && phone.present?
    user
  end

  def find_agent_for_params(unique_external_id, email, phone)
    user = nil
    user = Account.current.users.where(:unique_external_id => unique_external_id, :helpdesk_agent => true, :deleted => false).first if unique_external_id.present?
    user = Account.current.users.where(:email => email, :helpdesk_agent => true, :deleted => false).first if user.nil? && email.present?
    user = find_agent_by_cti_phone(phone) if user.nil? && phone.present?
    user
  end


  def find_user_by_phone(phone)
      user = Account.current.users.where(phone: phone).first
      user = Account.current.users.where(mobile: phone).first if user.nil?
      user
  end

  def find_agent_by_cti_phone(responder_phone)
    responder_phone = options[:responder_phone]
    phone = Account.current.cti_phones.where(phone: responder_phone).first
    phone.present? ? phone.agent : nil
  end
end
