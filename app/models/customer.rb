class Customer < ActiveRecord::Base
  
  serialize :domains
    
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id
  attr_accessible :name,:description,:note,:domains ,:sla_policy_id
  
  belongs_to :account
  
  has_many :users , :class_name =>'User' ,:conditions =>{:deleted =>false}
  
  belongs_to :sla_policy, :class_name =>'Helpdesk::SlaPolicy'
  
  #Sphinx configuration starts
  define_index do
    indexes :name, :sortable => true
    indexes :description
    indexes :note
    
    has account_id
    has '0', :as => :deleted, :type => :boolean
    
    set_property :delta => :delayed
  end
  #Sphinx configuration ends here..
  
  before_create :check_sla_policy
  before_update :check_sla_policy
  
  has_many :tickets , :through =>:users , :class_name => 'Helpdesk::Ticket' ,:foreign_key => "requester_id"
  
  CUST_TYPES = [
    [ :customer,    "Customer",         1 ], 
    [ :prospect,    "Prospect",      2 ], 
    [ :partner,     "Partner",        3 ], 
   
   
  ]

  CUST_TYPE_OPTIONS = CUST_TYPES.map { |i| [i[1], i[2]] }
  CUST_TYPE_BY_KEY = Hash[*CUST_TYPES.map { |i| [i[2], i[1]] }.flatten]
  CUST_TYPE_BY_TOKEN = Hash[*CUST_TYPES.map { |i| [i[0], i[2]] }.flatten]
  
  
  #setting default sla
  def check_sla_policy
    
    if self.sla_policy_id.nil?      
      
      self.sla_policy_id = account.sla_policies.find_by_is_default(true).id
      
    end
    
  end
  
end
