class Admin::CannedResponse < ActiveRecord::Base
  
  set_table_name "admin_canned_responses"    
  
  belongs_to :account
 
  belongs_to :user

  attr_accessible :title, :content, :visibility, :content_html
  
  attr_accessor :visibility 
  
  unhtml_it :content
  
  has_one :accessible, 
    :class_name => 'Admin::UserAccess',
    :as => 'accessible',
    :dependent => :destroy
  
  has_many :agent_groups , :through =>:accessible , :foreign_key => "group_id" , :source => :group
  
   validates_length_of :title, :in => 3..240

  named_scope :accessible_for, lambda { |agent_user| 
    {
      :joins => %(JOIN admin_user_accesses acc ON acc.accessible_id = admin_canned_responses.id AND 
        acc.accessible_type = 'Admin::CannedResponse' LEFT JOIN agent_groups ON 
        acc.group_id=agent_groups.group_id), 
      :conditions => %(acc.VISIBILITY=%<visible_to_all>s OR agent_groups.user_id=%<user_id>i OR 
          (acc.VISIBILITY=%<only_me>s and acc.user_id=%<user_id>i )) % {
        :visible_to_all => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents], 
        :only_me => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
        :user_id => agent_user.id }
    }
  }
   
   after_create :create_accesible
   after_update :save_accessible
   
  def create_accesible     
    self.accessible = Admin::UserAccess.new( {:account_id => account_id }.merge(self.visibility)  )
    self.save
  end
  
  def save_accessible
    self.accessible.update_attributes(self.visibility)    
  end
  
  def self.my_canned_responses(user)
    self.find(:all, :joins =>"JOIN admin_user_accesses acc ON acc.accessible_id = admin_canned_responses.id AND acc.accessible_type = 'Admin::CannedResponse' LEFT JOIN agent_groups ON acc.group_id=agent_groups.group_id", :conditions =>["acc.VISIBILITY=#{Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]} OR agent_groups.user_id=#{user.id} OR (acc.VISIBILITY=#{Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]} and acc.user_id=#{user.id})"])
  end
end
