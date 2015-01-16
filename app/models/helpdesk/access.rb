class Helpdesk::Access < ActiveRecord::Base
  set_table_name "helpdesk_accesses"  
  
  concerned_with :user_access_methods,:group_access_methods
  belongs_to_account

  belongs_to :accessible, :polymorphic => true  

  has_many :group_accesses
  has_many :user_accesses
            
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
  ACCESS_TYPES_KEYS_BY_TYPE = Hash[*ACCESS_TYPES.map { |i| [i[2], i[0]] }.flatten]
  ACCESS_TYPES_KEYS = ACCESS_TYPES.map{|i| i[0].to_s.singularize}

  ACCESS_TYPES_KEYS.product(ACCESS_TYPES_KEYS).each do |types|
    define_method("update_#{types[0]}_access_type_to_#{types[1]}") do |new_ids|
      if types[1] == types[0]
        send("update_#{types[0]}_accesses",new_ids)
      else
        send("remove_#{types[0]}_accesses",nil)
        send("create_#{types[1]}_accesses",new_ids)
      end
    end
  end

#This method is for handling self.alls in the above define_method.
  def alls 
    []
  end

  def access_type_str
    Helpdesk::Access::ACCESS_TYPES_KEYS[self.access_type]
  end

  def visible_to_me?
    if global_access_type?
      true
    elsif group_access_type?
      agent_groups   = account.agent_groups.find_all_by_user_id(User.current.id, :select => "group_id").collect(&:group_id)
      access_groups = group_accesses.collect(&:group_id)
      (agent_groups & access_groups).any?
    else
      user_accesses.first.user_id == User.current.id
    end
  end
  
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
      "LEFT JOIN agent_groups ON agent_groups.group_id = group_accesses.group_id AND 
          agent_groups.account_id = group_accesses.account_id"
    end

    def all_user_accessible_sql(type,user)
      self.send(:construct_finder_sql,:select => "accessible_id, accessible_type, access_type, helpdesk_accesses.account_id",
        :joins => "#{user_accesses_join(type, user)} #{group_accesses_join(type, user)} #{agent_groups_join}",
        :conditions => "#{type_conditions(type)} AND (#{user_conditions(user).values.join(' OR ')})")
    end
  end
        
  named_scope :user_accessible_items_via_group, lambda { |type, user|
    {
      :joins      => "#{group_accesses_join(type, user)} #{agent_groups_join}" ,
      :conditions => "#{type_conditions(type)} AND (#{user_conditions(user)[:global]} OR #{user_conditions(user)[:users_via_group]})",
      :select     => "accessible_id, accessible_type, access_type"  
    }  
  }
  
  # named_scope :all_user_accessible_items, lambda { |type, user|
  #   {
  #     :joins => "#{user_accesses_join(type, user)} #{group_accesses_join(type, user)} #{agent_groups_join}",
  #     :conditions => "#{type_conditions(type)} AND (#{user_conditions(user).values.join(' OR ')})" ,
  #     :select => "accessible_id, accessible_type, access_type"  
  #   } 
  # }
  
  # named_scope :user_accessible_items, lambda { |type, user|
  #   {
  #     :joins => "#{user_accesses_join(type, user)}",
  #     :conditions => "#{type_conditions(type)} AND (#{user_conditions(user)[:global]} OR #{user_conditions(user)[:users]})",
  #     :select => "accessible_id, accessible_type, access_type"
  #   }
  # }
  
  # named_scope :group_accessible_items, lambda { |type, group|
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
  
  
  # def user_access_type?
  #   access_type == ACCESS_TYPES_KEYS_BY_TOKEN[:users]
  # end
  def no_op(dummy)
  end

  alias_method :create_all_accesses, :no_op
  alias_method :remove_all_accesses, :no_op
  alias_method :update_all_accesses, :no_op
end
