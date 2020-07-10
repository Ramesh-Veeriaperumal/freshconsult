class Helpdesk::Access < ActiveRecord::Base
  self.table_name =  "helpdesk_accesses"  
  self.primary_key = :id
  
  concerned_with :user_access_methods,:group_access_methods
  belongs_to_account

  belongs_to :accessible, :polymorphic => true

  attr_accessor :group_changes

  has_many :user_accesses, class_name: 'Helpdesk::UserAccess'
  has_many :users, through: :user_accesses, class_name: 'User'

  has_many :group_accesses, class_name: 'Helpdesk::GroupAccess'
  has_many :groups,
           through: :group_accesses,
           class_name: 'Group',
           after_add: :touch_group_access_change,
           after_remove: :touch_group_access_change

  ACCESS_TYPES = [
    [ :all,   "Accessible by all",     0 ],
    [ :users, "Accessible by users", 1 ],
    [ :groups   ,   " Accessible by groups",      2 ]
  ]

  ACCESS_TYPES_KEYS_BY_TOKEN = Hash[*ACCESS_TYPES.map { |i| [i[0], i[2]] }.flatten]
  ACCESS_TYPES_KEYS_BY_TYPE = Hash[*ACCESS_TYPES.map { |i| [i[2], i[0]] }.flatten]
  ACCESS_TYPES_KEYS = ACCESS_TYPES.map{|i| i[0].to_s.singularize}

  DEFAULT_ACCESS_LIMIT = 300

  ACCESS_TYPES_KEYS.product(ACCESS_TYPES_KEYS).each do |types|
    define_method("update_#{types[0]}_access_type_to_#{types[1]}") do |new_ids|
      if types[1] == types[0]
        safe_send("update_#{types[0]}_accesses",new_ids)
      else
        safe_send("remove_#{types[0]}_accesses",nil)
        safe_send("create_#{types[1]}_accesses",new_ids)
      end
    end
  end

  #This method is for handling self.alls in the above define_method.
  def alls
    []
  end

  def touch_group_access_change(group_accesses)
    return unless group_accesses.id.present?

    if self.group_changes.present?
      self.group_changes.push(group_accesses.id)
    else
      self.group_changes = [group_accesses.id]
    end
  end

  def access_type_str
    Helpdesk::Access::ACCESS_TYPES_KEYS[self.access_type]
  end

  def visible_to_me?
    if global_access_type?
      true
    elsif group_access_type?
      agent_groups  = account.agent_groups.where(user_id: User.current.id).select('group_id').collect(&:group_id)
      access_groups = group_accesses.collect(&:group_id)
      (agent_groups & access_groups).any?
    else
      user_accesses.first.user_id == User.current.id
    end
  end

  def visible_to_only_me?
    user_access_type? and user_accesses.first.user_id == User.current.id
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
      'LEFT JOIN user_accesses ON
        helpdesk_accesses.id = user_accesses.access_id AND
        helpdesk_accesses.account_id = user_accesses.account_id'
    end

    def group_accesses_join(type, item)
      'LEFT JOIN group_accesses ON
        helpdesk_accesses.id = group_accesses.access_id
        AND helpdesk_accesses.account_id = group_accesses.account_id'
    end

    def agent_groups_join
      'LEFT JOIN agent_groups ON
        agent_groups.group_id = group_accesses.group_id AND
        agent_groups.account_id = group_accesses.account_id'
    end

    def all_accessible_sql(type, user)
      all_accessible(type, user).to_sql
    end

    def user_accessible_sql(type, user)
      user_accessible(type, user).to_sql
    end

    def group_accessible_sql(type, user)
      group_accessible(type, user).to_sql
    end

    def all_user_accessible_sql(type, user)
      "SELECT  accessible_id
        FROM (#{all_accessible(type, user).to_sql}
        UNION #{user_accessible(type, user).to_sql}
        UNION #{group_accessible(type, user, nil).to_sql})
        AS all_user_access_union GROUP BY accessible_id"
    end

    def shared_accessible_sql(type,user)
      self.safe_send(:construct_finder_sql,:select => "accessible_id, accessible_type, access_type, helpdesk_accesses.account_id",
        :joins => "#{group_accesses_join(type, user)} #{agent_groups_join}",
        :conditions => "#{type_conditions(type)} AND (#{user_conditions(user)[:global]} OR #{user_conditions(user)[:users_via_group]})")
    end

    def only_me_accessible_sql(type,user)
      self.safe_send(:construct_finder_sql,:select => "accessible_id, accessible_type, access_type, helpdesk_accesses.account_id",
        :joins => "#{user_accesses_join(type, user)}",
        :conditions => "#{type_conditions(type)} AND (#{user_conditions(user)[:users]})")
    end
  end

  scope :user_accessible_items_via_group, ->(type, user) {
    where("#{type_conditions(type)} AND (#{user_conditions(user)[:global]} OR #{user_conditions(user)[:users_via_group]})").
    select('accessible_id, accessible_type, access_type').
    joins("#{group_accesses_join(type, user)} #{agent_groups_join}")
  }

  scope :all_accessible, lambda { |type, user|
    select('accessible_id')
      .where(sanitize_sql_for_conditions(["#{type_conditions(type)} AND #{user_conditions(user)[:global]}"]))
  }

  scope :user_accessible, lambda { |type, user|
    select('accessible_id')
      .joins(user_accesses_join(type, user).to_s)
      .where(sanitize_sql_for_conditions(["#{type_conditions(type)} AND #{user_conditions(user)[:users]}"]))
  }

  scope :group_accessible, lambda { |type, user, group_by_column = 'accessible_id'|
    select('accessible_id')
      .joins("#{group_accesses_join(type, user)} #{agent_groups_join}")
      .where("#{type_conditions(type)} AND #{user_conditions(user)[:users_via_group]}")
      .group(group_by_column)
  }

  def global_access_type?
    access_type == ACCESS_TYPES_KEYS_BY_TOKEN[:all]
  end

  def group_access_type?
    access_type == ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
  end


  def user_access_type?
    access_type == ACCESS_TYPES_KEYS_BY_TOKEN[:users]
  end

  def no_op(dummy)
  end

  alias_method :create_all_accesses, :no_op
  alias_method :remove_all_accesses, :no_op
  alias_method :update_all_accesses, :no_op
end
