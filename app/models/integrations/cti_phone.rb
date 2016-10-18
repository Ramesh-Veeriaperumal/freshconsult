class Integrations::CtiPhone < ActiveRecord::Base
  self.table_name =  :cti_phones

  belongs_to_account
  belongs_to :agent, :class_name => '::User', :conditions => 'users.helpdesk_agent = true', :foreign_key => 'agent_id'
  validate :is_user_agent?
  validates :phone, presence: true
  belongs_to :installed_application, :class_name => 'Integrations::InstalledApplication'
  before_create :populate_installed_app
  before_save :remove_existing_association

  def remove_existing_association
    return unless self.agent
    cti_phone = Account.current.cti_phones.where(:agent_id => self.agent_id).first
    if cti_phone.present? && cti_phone.id != self.id
      cti_phone.update_column(:agent_id, nil)
    end
  end

  def populate_installed_app
    self.installed_application_id = Account.current.cti_installed_app_from_cache.id
  end

  def is_user_agent?
    errors.add(:user, "#{agent.name} is not an Agent") unless agent.blank? || agent.helpdesk_agent?
  end

end
