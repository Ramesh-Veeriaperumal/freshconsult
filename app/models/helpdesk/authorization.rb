class Helpdesk::Authorization < ActiveRecord::Base
  set_table_name "helpdesk_authorizations"

  belongs_to :user

  ROLE_OPTIONS = Helpdesk::ROLES.map { |k, v| [v[:title], k.to_s] }.reject { |p| !p[0] }

  validates_presence_of :role_token, :user_id
  validates_inclusion_of :role_token, :in => Helpdesk::ROLES.stringify_keys.keys
  validates_uniqueness_of :user_id

  def role
    @role ||= Helpdesk::ROLES[role_token.to_sym] || Helpdesk::ROLES[:customer]
  end

  def name
    user.name
  end

  def permission?(p)
    role[:permissions][p]
  end

  def self.find_all_by_permission(p)
    self.find(:all).select { |a| a.permission?(p) }
  end

end
