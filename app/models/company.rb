# encoding: utf-8
class Company < ActiveRecord::Base
  
  self.table_name = :customers
  self.primary_key = :id
  
  include Cache::Memcache::Company
  include Search::ElasticSearchIndex
  include Mobile::Actions::Company
  include InstalledAppBusinessRules::Methods

  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id , :case_sensitive => false
  attr_accessible :name,:description,:note,:domains ,:sla_policy_id, :import_id,
                  :domain_name, :health_score, :account_tier, :renewal_date, :industry
  attr_accessor :highlight_name, :escape_liquid_attributes, :validatable_default_fields

  xss_sanitize  :only => [:name], :plain_sanitizer => [:name]
  alias_attribute :domain_name, :domains

  validate :format_of_default_fields, :if => :validatable_default_fields

  DEFAULT_DROPDOWN_FIELDS = [:default_health_score, :default_account_tier, :default_industry]
  TAM_DEFAULT_FIELDS = [:default_health_score, :default_account_tier, :default_industry, :default_renewal_date]


  TAM_DEFAULT_FIELD_MAPPINGS = {
    :string_cc01        =>    :health_score,
    :string_cc02        =>    :account_tier,
    :string_cc03        =>    :industry,
    :datetime_cc01      =>    :renewal_date
  }

  TAM_DEFAULT_FIELD_MAPPINGS.keys.each do |key|
    alias_attribute(TAM_DEFAULT_FIELD_MAPPINGS[key], key)
  end
  
  concerned_with :associations, :callbacks, :esv2_methods, :rabbitmq

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

  def custom_form
    (Account.current || account).company_form
  end

  def custom_field_aliases 
    @custom_field_aliases ||= custom_form.custom_company_fields.map(&:name)
  end

  def custom_field_types
    @custom_field_types ||=  custom_form.custom_company_fields.inject({}) { |types,field| types.merge(field.name => field.field_type) }
  end

  def domain_list
    self.company_domains.loaded? ? self.company_domains.map(&:domain) : self.company_domains.pluck(:domain)
  end

  def domains
    @domain_str ||= domain_list.join(',')
  end

  def domains=(domain_str)
    @domain_str = domain_str
    old_domains = domain_list
    new_domains = domains_array(domain_str)
    added_domains = new_domains - old_domains
    removed_domains = old_domains - new_domains
    self.company_domains_attributes = [domain_hash_list(added_domains), domain_hash_list(removed_domains,true)].flatten
  end

  def tickets
    all_tickets.joins(:requester).where('users.deleted =?', false)
  end

  def format_of_default_fields
    error_label = validatable_default_fields[:error_label]
    fields      = validatable_default_fields[:fields]

    fields.each do |field|
      if DEFAULT_DROPDOWN_FIELDS.include?(field.field_type)
        validation_method = "validate_format_of_default_dropdown"
      else
        validation_method = "no_op"
      end
      if respond_to?(validation_method, true)
        send(validation_method, field, error_label) if send(field.name).present?
      else
        warn :"Validation Method #{validation_method} is not present for the #{field.field_type} - #{field.inspect}"
      end
    end
  end

  def validate_format_of_default_dropdown field, error_label
    add_error_to_self(field, error_label) unless field.choices_value.include? send(field.name)
  end

  def no_op field, error_label
  end

  def add_error_to_self field, error_label
    self.errors.add( field.send(error_label), 
      I18n.t("#{self.class.to_s.downcase}.errors.default_dropdown"))
  end

  def choices_value
    custom_field_choices.map{|choice| choice[:value]}
  end

  TAM_DEFAULT_FIELD_MAPPINGS.keys.each do |attribute|
    define_method("#{attribute}") do
      self.flexifield.send(attribute)
    end

    define_method("#{attribute}?") do
      self.flexifield.send(attribute)
    end

    define_method("#{attribute}=") do |value|
      value = value.to_time if attribute == :datetime_cc01
      self.flexifield.send("#{attribute}=", value)
    end
  end

  private

    def domains_array(domains)
      domains ||= ""
      domains.split(",").collect(&:strip).reject(&:blank?).uniq
    end

    def domain_hash_list(domains_list, destroy=false)
      domain_id_hash = pluck_domain_id
      domains_list.collect do |dom|
        id = domain_id_hash[dom]
        {:id=>id, :domain=>dom, :_destroy=>destroy}
      end
    end

    def pluck_domain_id
      self.company_domains.inject({}) {|h,cd| h[cd.domain]=cd.id; h }
    end
end
