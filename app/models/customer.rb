# encoding: utf-8
class Customer < ActiveRecord::Base
  
  include Cache::Memcache::Customer
  include Search::ElasticSearchIndex
  include Mobile::Actions::Customer
  include ObserverAfterCommitCallbacks
  serialize :domains
    
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id , :case_sensitive => false
  attr_accessible :name,:description,:note,:domains ,:sla_policy_id, :import_id
  attr_accessor :highlight_name
  
  belongs_to_account
  
  has_many :users , :class_name =>'User' ,:conditions =>{:deleted =>false} , :dependent => :nullify , :order => :name
  
  has_many :all_users , :class_name =>'User' , :dependent => :nullify , :order => :name

  has_many :all_tickets ,:class_name => 'Helpdesk::Ticket', :through => :all_users , :source => :tickets
  
  has_many :tickets , :through => :users , :class_name => 'Helpdesk::Ticket'

  has_many :customer_folders, :class_name => 'Solution::CustomerFolder', :dependent => :destroy

  scope :domains_like, lambda { |domain|
    { :conditions => [ "domains like ?", "%#{domain}%" ] } if domain
  }

  after_commit :map_contacts_to_customers, :clear_cache, on: :create
  #https://github.com/rails/rails/issues/988#issuecomment-31621550
  after_commit ->(obj) { obj.clear_cache }, on: :destroy
  after_commit ->(obj) { obj.clear_cache }, on: :update
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

  scope :custom_search, lambda { |search_string| 
    { :conditions => ["name like ?" ,"%#{search_string}%"],
      :select => "name, id",
      :limit => 1000  }
  }
  
  def self.filter(letter, page, per_page = 50)
  paginate :per_page => per_page, :page => page,
           :conditions => ['name like ?', "#{letter}%"],
           :order => 'name'
  end
  
  def self.es_filter(account_id, letter, page, field_name, sort_order, per_page)
    Search::EsIndexDefinition.es_cluster(account_id)
    index_name = Search::EsIndexDefinition.searchable_aliases([Customer], account_id)
    options = {:load => true, :page => page, :size => per_page, :preference => :_primary_first }
    items = Tire.search(index_name, options) do |search|
      search.query do |query|
        query.filtered do |f|
          if(letter)
            f.query { |q| q.string SearchUtil.es_filter_key(letter) }
          else
            f.query { |q| q.string '*' }
          end
          f.filter :term, { :account_id => account_id }
        end
      end
      search.from options[:size].to_i * (options[:page].to_i-1)
      search.sort { by field_name, sort_order } 
    end
    search_results = []
    items.results.each_with_hit do |result, hit|
      search_results.push(result)
    end
    search_results
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
      xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:except => [:account_id,:import_id,:delta]) 
  end

  def to_indexed_json
    to_json( 
              :root => "customer",
              :tailored_json => true,
              :only => [ :name, :note, :description, :account_id, :created_at, :updated_at ] 
           )
  end
  
  def as_json(options = {})# TODO-RAILS3
    return super(options) unless options[:tailored_json].blank?
    options[:except] = [:account_id,:import_id,:delta]
    json_hash = super options
    json_hash
  end

  def to_liquid
    @company_drop ||= CompanyDrop.new self
  end

  protected

    def search_fields_updated?
      all_fields = ["name", "description", "note"]
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
    end
  
end
