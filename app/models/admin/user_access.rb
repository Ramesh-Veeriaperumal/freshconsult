class Admin::UserAccess < ActiveRecord::Base
  set_table_name "admin_user_accesses"  
  
  belongs_to :accessible, :polymorphic => true  
  belongs_to :account
  belongs_to :user
  belongs_to :group
  
  VISIBILITY = [
  [ :all_agents,   "All agents",     1 ], 
  [ :group_agents, "Agents in group", 2 ],
  [ :only_me   ,   "Me only",      3 ]
  ]
  
  VISIBILITY_OPTIONS = VISIBILITY.map { |i| [i[1], i[2]] }
  VISIBILITY_NAMES_BY_KEY = Hash[*VISIBILITY.map { |i| [i[2], i[1]] }.flatten] 
  VISIBILITY_KEYS_BY_TOKEN = Hash[*VISIBILITY.map { |i| [i[0], i[2]] }.flatten] 
  
  before_save :check_visibility
  
  def check_visibility
    if !group_agents_visibility?
      self.group_id = nil
    end
    self.visibility = VISIBILITY_KEYS_BY_TOKEN[:only_me] if visibility.blank?
  end
  
  def group_agents_visibility?
    visibility == VISIBILITY_KEYS_BY_TOKEN[:group_agents]
  end
  
end
