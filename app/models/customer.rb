# encoding: utf-8
class Customer < ActiveRecord::Base
  
  include Cache::Memcache::Customer
  include Search::ElasticSearchIndex
  include Mobile::Actions::Customer
  serialize :domains
    
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id , :case_sensitive => false
  attr_accessible :name,:description,:note,:domains ,:sla_policy_id, :import_id
  attr_accessor :highlight_name
  
  belongs_to_account
  
  has_many :users , :class_name =>'User' ,:conditions =>{:deleted =>false} , :dependent => :nullify , :order => :name
  
  has_many :all_users , :class_name =>'User' , :dependent => :nullify , :order => :name
  
  has_many :tickets , :through => :users , :class_name => 'Helpdesk::Ticket'

  has_many :customer_folders, :class_name => 'Solution::CustomerFolder', :dependent => :destroy

  named_scope :domains_like, lambda { |domain|
    { :conditions => [ "domains like ?", "%#{domain}%" ] } if domain
  }

  after_commit_on_create :map_contacts_to_customers, :clear_cache
  after_commit_on_destroy :clear_cache
  after_commit_on_update :clear_cache
  after_update :map_contacts_on_update, :if => :domains_changed?
  
  before_create :check_sla_policy
  before_update :check_sla_policy, :backup_customer_changes
  
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
  
  def self.filter(letter, page, per_page = 50)
  paginate :per_page => per_page, :page => page,
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
    to_json( 
              :root => "customer",
              :tailored_json => true,
              :only => [ :name, :note, :description, :account_id ] 
           )
  end
  
  def to_json(options = {})
    return super(options) unless options[:tailored_json].blank?
    options[:except] = [:account_id,:import_id,:delta]
    json_str = super options
    json_str
  end

  def sla_policy_in_use
    self.account.sla_policies.each do |sla_policy|
      next if sla_policy.conditions.nil? || sla_policy.conditions["company_id"].nil?
      if sla_policy.conditions["company_id"].include?(self.id)
        return sla_policy
      end
    end
    self.account.sla_policies.default.first
  end

  def to_liquid
    @company_drop ||= CompanyDrop.new self
  end

  protected

    def search_fields_updated?
      all_fields = [:name, :description, :note]
      (@model_changes.keys & all_fields).any?
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
        ['SUBSTRING_INDEX(email, "@", -1) IN (?) and customer_id is null and account_id = ?', 
        get_domain(domains), self.account_id]) unless domains.blank?
    end

    def get_domain(domains)
      domains.split(",").map{ |s| s.gsub(/^(\s)?(http:\/\/)?(www\.)?/,'').gsub(/\/.*$/,'') }
    end

    def backup_customer_changes
      @model_changes = self.changes.clone
      @model_changes.symbolize_keys!
    end
  
end
