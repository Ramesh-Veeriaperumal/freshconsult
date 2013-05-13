# encoding: utf-8
class Customer < ActiveRecord::Base
  
  include Cache::Memcache::Customer
  include Search::ElasticSearchIndex
  serialize :domains
    
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id , :case_sensitive => false
  attr_accessible :name,:description,:note,:domains ,:sla_policy_id, :import_id
  
  belongs_to :account
  
  has_many :users , :class_name =>'User' ,:conditions =>{:deleted =>false} , :dependent => :nullify , :order => :name
  
  has_many :all_users , :class_name =>'User' , :dependent => :nullify , :order => :name
  
  has_many :tickets , :through => :users , :class_name => 'Helpdesk::Ticket'

  has_many :customer_folders, :class_name => 'Solution::CustomerFolder', :dependent => :destroy
  
  belongs_to :sla_policy, :class_name =>'Helpdesk::SlaPolicy'

  named_scope :domains_like, lambda { |domain|
    { :conditions => [ "domains like ?", "%#{domain}%" ] } if domain
  }

  after_commit_on_create :map_contacts_to_customers, :clear_cache, :update_es_index
  after_commit_on_destroy :clear_cache, :remove_es_document
  after_commit_on_update :clear_cache, :update_es_index
  after_update :map_contacts_on_update, :if => :domains_changed?
   
  #Sphinx configuration starts
  define_index do
    indexes :name, :sortable => true
    indexes :description
    indexes :note
    
    has account_id
    has '0', :as => :deleted, :type => :boolean
    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :responder_id, :type => :integer
    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :group_id, :type => :integer
    #set_property :delta => :delayed
    set_property :field_weights => {
      :name         => 10,
      :note         => 4,
      :description  => 3
    }
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

  named_scope :custom_search, lambda { |search_string| 
    { :conditions => ["name like ?" ,"%#{search_string}%"],
      :select => "name, id",
      :limit => 1000  }
  }
  
  def self.filter(letter, page)
  paginate :per_page => 10, :page => page,
           :conditions => ['name like ?', "#{letter}%"],
           :order => 'name'
  end
  
  #setting default sla
  def check_sla_policy    
    if self.sla_policy_id.nil?            
      self.sla_policy_id = account.sla_policies.find_by_is_default(true).id      
    end    
  end

  def to_s
    self.name
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:except => [:account_id,:import_id,:delta]) 
  end

  def to_indexed_json
    to_json( :only => [ :name, :note, :description, :account_id ] )
  end
  
  def to_json(options = {})
    options[:except] = [:account_id,:import_id,:delta]
    json_str = super options
    json_str
  end

  private
    def map_contacts_on_update
      domain_changes = self.changes["domains"].compact
      domain_changes[0].split(",").map { |domain| 
                    domain_changes[1].gsub!( /(^#{domain}\s?,)|(,?\s?#{domain})/, '') } if domain_changes[1]
      map_contacts_to_customers(domain_changes[1].blank? ? domain_changes[0] : domain_changes[1])
    end

    def map_contacts_to_customers(domains = self.domains)
      User.update_all("customer_id = #{self.id}", 
        ['SUBSTRING_INDEX(email, "@", -1) IN (?) and customer_id is null and helpdesk_agent = false and account_id = ?', 
        get_domain(domains), self.account_id]) unless domains.blank?
    end

    def get_domain(domains)
      domains.split(",").map{ |s| s.gsub(/^(\s)?(http:\/\/)?(www\.)?/,'').gsub(/\/.*$/,'') }
    end
  
end
