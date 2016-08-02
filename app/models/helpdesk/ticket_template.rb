class Helpdesk::TicketTemplate < ActiveRecord::Base

  include Search::ElasticSearchIndex
  include Helpdesk::Accessible::ElasticSearchMethods
  include Cache::Memcache::Helpdesk::TicketTemplate
  include SanitizeSerializeValues
  
  self.table_name =  "ticket_templates"    
  self.primary_key = :id

  belongs_to_account

  TOTAL_SHARED_TEMPLATES = 300

  ASSOCIATION_TYPES = [
    [ :general, "General Template", 1 ],
    [ :parent, "Parent Template", 2 ],
    [ :child , "Child Template",  3 ]
  ]

  ASSOCIATION_TYPES_KEYS_BY_TOKEN = Hash[*ASSOCIATION_TYPES.map { |i| [i[0], i[2]] }.flatten]
  ASSOCIATION_TYPES_KEYS_BY_TYPE = Hash[*ASSOCIATION_TYPES.map { |i| [i[2], i[0]] }.flatten]

  serialize :template_data, Hash

  has_many_attachments 

  has_many_cloud_files

  #https://github.com/rails/rails/issues/988#issuecomment-31621550
  after_commit ->(obj) { obj.clear_template_count_cache }, on: :create
  after_commit ->(obj) { obj.clear_template_count_cache }, on: :destroy

  has_one :accessible,
    :class_name => 'Helpdesk::Access',
    :as         => 'accessible',
    :dependent  => :destroy

  has_many :shared_attachments,
    :as         => :shared_attachable,
    :class_name => 'Helpdesk::SharedAttachment',
    :dependent  => :destroy

  has_many :attachments_sharable, 
    :through    => :shared_attachments, 
    :source     => :attachment

  attr_accessible :name, :description, :template_data, :accessible_attributes
  xss_sanitize :only => [:name, :description], :html_sanitize => [:name, :description], :decode_calm_sanitizer => [:data_description_html]

  before_validation :set_default_type, :validate_name
  accepts_nested_attributes_for :accessible
  alias_attribute :helpdesk_accessible, :accessible
  delegate :groups, :users, :visible_to_me?,:visible_to_only_me?, :to => :accessible

  scope :shared_templates, lambda { |user|
    {
      :joins => %(JOIN helpdesk_accesses acc ON
                  acc.accessible_id = ticket_templates.id AND
                  acc.accessible_type = 'Helpdesk::TicketTemplate' AND
                  ticket_templates.account_id=%<account_id>i AND
                  acc.account_id = ticket_templates.account_id) % { :account_id => user.account_id },
      :conditions => %(acc.access_type!=%<users>s) % {
        :users => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
      }, 
      :order => "name"
    }
  }

  scope :only_me, lambda { |user|
    {
      :joins => %(JOIN helpdesk_accesses acc ON
                  acc.accessible_id = ticket_templates.id AND
                  acc.accessible_type = 'Helpdesk::TicketTemplate' AND
                  ticket_templates.account_id=%<account_id>i AND
                  acc.account_id = ticket_templates.account_id
                  inner join user_accesses ON acc.id= user_accesses.access_id AND
                  acc.account_id= user_accesses.account_id) % { :account_id => user.account_id },
      :conditions => %(acc.access_type=%<only_me>s and user_accesses.user_id=%<user_id>i ) % {
        :only_me => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
        :user_id => user.id
      }, 
      :order => "name"
    }
  }

  INCLUDE_ASSOCIATIONS_BY_CLASS = {
    Helpdesk::TicketTemplate => {:include => [{:accessible => [:group_accesses, :user_accesses]}]}
  }

  def set_default_type
    self.association_type ||= ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general]
  end

  def to_indexed_json
   as_json({
     :root => "helpdesk/ticket_template", 
     :tailored_json => true, 
     :only => [:account_id, :name, :association_type],
     :methods => [:es_access_type, :es_group_accesses, :es_user_accesses],
     }).to_json
  end

  def all_attachments
    @all_attachments ||= begin
      shared_attachments = self.attachments_sharable
      individual_attachments = self.attachments
      individual_attachments + shared_attachments
    end
  end

  def sanitize_template_data data_hash
    sanitize_hash_values data_hash
  end

  private

  def validate_name
    if !self.accessible.user_access_type? && (self.name_changed? || access_type_changed?)
      templ_ids = Account.current.ticket_templates.shared_templates(User.current).where(:name => self.name).pluck(:id)
      templ_ids = templ_ids.select{|id| id != self.id} if !self.new_record?
      unless templ_ids.empty?
        self.errors.add(:base, I18n.t("ticket_templates.errors.duplicate_title"))
        return false
      end
    end
    true
  end

  def access_type_changed?
    if (!self.new_record? and self.accessible.access_type_changed?)
      return (self.accessible.changes.fetch("access_type")[0] == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users])
    end
    false
  end

  def sanitize_hash_values(inputs_hash)
    inputs_hash.each do |key, value|
      next if (key == "description_html" || value.blank? || [true,false].include?(value))
      inputs_hash[key] = sanitize_value(value)
    end
  end
end