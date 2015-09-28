# encoding: utf-8
class Company < ActiveRecord::Base
  
  self.table_name = :customers
  self.primary_key = :id
  
  include Cache::Memcache::Company
  include Search::ElasticSearchIndex
  include Mobile::Actions::Company
  serialize :domains

  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id , :case_sensitive => false
  attr_accessible :name,:description,:note,:domains ,:sla_policy_id, :import_id, :domain_name
  attr_accessor :highlight_name

  xss_sanitize  :only => [:name], :plain_sanitizer => [:name]
  alias_attribute :domain_name, :domains
  
  concerned_with :associations, :callbacks, :es_methods, :rabbitmq

  scope :domains_like, lambda { |domain|
    { :conditions => [ "domains like ?", "%#{domain}%" ] } if domain
  }

  scope :custom_search, lambda { |search_string| 
    { :conditions => ["name like ?" ,"%#{search_string}%"],
      :select => "name, id, account_id",
      :limit => 1000  }
  }  
  
  CUST_TYPES = [
    [ :customer,    "Customer",      1 ], 
    [ :prospect,    "Prospect",      2 ], 
    [ :partner,     "Partner",       3 ], 
  ]

  CUST_TYPE_OPTIONS = CUST_TYPES.map { |i| [i[1], i[2]] }
  CUST_TYPE_BY_KEY = Hash[*CUST_TYPES.map { |i| [i[2], i[1]] }.flatten]
  CUST_TYPE_BY_TOKEN = Hash[*CUST_TYPES.map { |i| [i[0], i[2]] }.flatten]

  def self.filter(letter, page, per_page = 50)
    paginate :per_page => per_page, :page => page,
             :conditions => ['name like ?', "#{letter}%"],
             :order => 'name'
  end
  
  def self.es_filter(account_id, letter,page, field_name, sort_order, per_page)
    Search::EsIndexDefinition.es_cluster(account_id)
    index_name = Search::EsIndexDefinition.searchable_aliases([Customer], account_id)
    options = {:load => { Company => { :include => [:flexifield] }} , :page => page, :size => per_page, :preference => :_primary_first }
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

  def to_s
    self.name
  end
  
  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    options[:skip_instruct] ||= true
    options[:except]        ||= [:account_id,:import_id,:delta]
    super options do |builder|
      builder.custom_field do
        custom_field.each do |name, value|
          builder.tag!(name,value) unless value.nil?
        end
      end
    end
  end

  def as_json(options = {}) # Any change in to_json or as_json needs a change in elasticsearch as well
    return super(options) unless options[:tailored_json].blank?
    options[:methods] = options[:methods].blank? ? [:custom_field] : options[:methods].push(:custom_field)
    options[:except] = [:account_id,:import_id,:delta]
    super options
  end

  def to_liquid
    @company_drop ||= CompanyDrop.new self
  end

  def search_fields_updated?
    (@model_changes.keys & es_columns).any?
  end

  def custom_form
    (Account.current || account).company_form
  end

  def custom_field_aliases 
    @custom_field_aliases ||= custom_form.custom_company_fields.map(&:name)
  end

  def custom_field_types
    @custom_field_types ||=  custom_form.custom_company_fields.inject({}) { |types,field| types.merge(field.name => field.field_type) }
  end
  
end