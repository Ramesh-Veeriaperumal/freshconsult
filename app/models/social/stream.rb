class Social::Stream < ActiveRecord::Base

  self.table_name =  "social_streams"
  self.primary_key = :id
  belongs_to_account

  serialize :data, Hash
  serialize :includes, Array
  serialize :excludes, Array
  serialize :filter, Hash

  validates_presence_of :account_id

  has_many :ticket_rules,
    :class_name  => 'Social::TicketRule',
    :foreign_key => :stream_id,
    :dependent   => :destroy,
    :order       => :position

  has_one :accessible,
    :class_name => "Helpdesk::Access",
    :as => :accessible,
    :dependent => :destroy

  delegate :groups, :users, :to => :accessible
  
  accepts_nested_attributes_for :accessible

  def create_global_access
    accessible = self.create_accessible(:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all] ) if accessible.nil?
  end

  def populate_accessible(access_type)
    accessible = self.create_accessible(:access_type => access_type ) if accessible.nil?
  end

  def search_keys_to_s
    includes.blank? ? "" : includes.join(",")
  end

  def excludes_to_s
    excludes.blank? ? "" : excludes.join(",")
  end

  def user_access?(user)
    return true if accessible.global_access_type?
    
    agent_groups = self.groups.map { |group| group.agent_groups }.flatten
    accessible_user_ids_in_groups = agent_groups.map {|agent_group| agent_group.user_id }
    
    (accessible.group_access_type? &&  accessible_user_ids_in_groups.include?(user.id))
  end
  
  def dynamo_stream_id
     "#{self.account_id}_#{self.id}"
  end
end
