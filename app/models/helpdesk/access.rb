class Helpdesk::Access < ActiveRecord::Base
  self.table_name =  "helpdesk_accesses"  
  
  belongs_to_account

  belongs_to :accessible, :polymorphic => true  
            
  has_and_belongs_to_many :users,
    :join_table => 'user_accesses'
  
  has_and_belongs_to_many :groups,
    :join_table => 'group_accesses'


  ACCESS_TYPES = [
    [ :all,   "Accessible by all",     0 ], 
    [ :users, "Accessible by users", 1 ],
    [ :groups   ,   " Accessible by groups",      2 ]
  ]
  
  ACCESS_TYPES_KEYS_BY_TOKEN = Hash[*ACCESS_TYPES.map { |i| [i[0], i[2]] }.flatten] 

  
  class << self
  
    def user_conditions(user)
      permissions = {
        :global => "helpdesk_accesses.access_type = #{ACCESS_TYPES_KEYS_BY_TOKEN[:all]}",
        :users => "(helpdesk_accesses.access_type = #{ACCESS_TYPES_KEYS_BY_TOKEN[:users]} AND user_accesses.user_id = #{user.id})",
        :users_via_group => " (helpdesk_accesses.access_type = #{ACCESS_TYPES_KEYS_BY_TOKEN[:groups]} AND agent_groups.user_id = #{user.id})" 
      }
    end
    
    def group_conditions(group)
      permissions = {
        :global => "helpdesk_accesses.access_type = #{ACCESS_TYPES_KEYS_BY_TOKEN[:all]}",
        :groups => "(helpdesk_accesses.access_type = #{ACCESS_TYPES_KEYS_BY_TOKEN[:groups]} AND group_accesses.group_id = #{group.id})"
      }
    end
    
    def type_conditions(type)
      "helpdesk_accesses.accessible_type = \'#{type}\' "
    end
    
    def user_accesses_join(type, item)
      "LEFT JOIN user_accesses ON
        helpdesk_accesses.account_id = #{item.account_id} AND
        helpdesk_accesses.accessible_type = \'#{type}\' AND
        helpdesk_accesses.id = user_accesses.access_id AND
        helpdesk_accesses.account_id = user_accesses.account_id"
    end
    
    def group_accesses_join(type, item)
      "LEFT JOIN group_accesses ON 
          helpdesk_accesses.account_id = #{item.account_id} AND
          helpdesk_accesses.accessible_type = \'#{type}\' AND
          helpdesk_accesses.id = group_accesses.access_id AND
          helpdesk_accesses.account_id = group_accesses.account_id"
    end
    
    def agent_groups_join
      "LEFT JOIN agent_groups ON agent_groups.group_id = group_accesses.group_id"
    end
  end
        
  scope :user_accessible_items_via_group, lambda { |type, user|
    {
      :joins      => "#{group_accesses_join(type, user)} #{agent_groups_join}" ,
      :conditions => "#{type_conditions(type)} AND (#{user_conditions(user)[:global]} OR #{user_conditions(user)[:users_via_group]})",
      :select     => "accessible_id, accessible_type, access_type"  
    }  
  }
  
  # scope :all_user_accessible_items, lambda { |type, user|
  #   {
  #     :joins => "#{user_accesses_join(type, user)} #{group_accesses_join(type, user)} #{agent_groups_join}",
  #     :conditions => "#{type_conditions(type)} AND (#{user_conditions(user).values.join(' OR ')})" ,
  #     :select => "accessible_id, accessible_type, access_type"  
  #   } 
  # }
  
  # scope :user_accessible_items, lambda { |type, user|
  #   {
  #     :joins => "#{user_accesses_join(type, user)}",
  #     :conditions => "#{type_conditions(type)} AND (#{user_conditions(user)[:global]} OR #{user_conditions(user)[:users]})",
  #     :select => "accessible_id, accessible_type, access_type"
  #   }
  # }
  
  # scope :group_accessible_items, lambda { |type, group|
  #   {
  #     :joins => "#{group_accesses_join(type, group)}",
  #     :conditions => "#{type_conditions(type)} AND (#{group_conditions(group)[:global]} OR #{group_conditions(group)[:groups]})",
  #     :select => "accessible_id, accessible_type, access_type"    
  #   } 
  # }
  
  def global_access_type?
    access_type == ACCESS_TYPES_KEYS_BY_TOKEN[:all]
  end
   
  def group_access_type?
     access_type == ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
  end
  
  def create_group_accesses(group_ids)
    groups = Account.current.groups.find(:all, :conditions => { :id => group_ids })
    groups.each do |group|
      self.groups << group
    end
  end
  
  def remove_group_accesses(group_ids)
    groups = Account.current.groups.find(:all, :conditions => { :id => group_ids })
    groups.each do |group|
      self.groups.delete(group)
    end
  end
  
  # def user_access_type?
  #   access_type == ACCESS_TYPES_KEYS_BY_TOKEN[:users]
  # end
  
  # def create_user_accesses(user_ids)
  #   users = Account.current.users.find(:all, :conditions => { :id => user_ids })
  #   users.each do |user|
  #     self.users << user
  #   end
  # end
  
  # def remove_user_accesses(user_ids)
  #   users = Account.current.users.find(:all, :conditions => { :id => user_ids })
  #   users.each do |user|
  #     self.users.delete(user)
  #   end
  # end

end
