class Admin::CannedResponse < ActiveRecord::Base
  
  set_table_name "admin_canned_responses"    
  
  belongs_to :account
 
  belongs_to :user
  

  attr_accessible :title,:content ,:visibility
  
  attr_accessor :visibility 
  
  has_one :accessible, 
    :class_name => 'Admin::UserAccess',
    :as => 'accessible',
    :dependent => :destroy
  
  has_many :agent_groups , :through =>:accessible , :foreign_key => "group_id" , :source =>:group
  
   validates_length_of :title, :in => 3..240
   
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
