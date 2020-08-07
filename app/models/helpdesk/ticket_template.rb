class Helpdesk::TicketTemplate < ActiveRecord::Base

  include Cache::Memcache::Helpdesk::TicketTemplate
  include SanitizeSerializeValues

  self.table_name =  "ticket_templates"
  self.primary_key = :id

  belongs_to_account

  TOTAL_SHARED_TEMPLATES = 300 #this max limit is for general and parent templates only.
  TOTAL_CHILD_TEMPLATES  = 10


  ASSOCIATION_TYPES = [
    [ :general, "General Template", 1 ],
    [ :parent, "Parent Template", 2 ],
    [ :child , "Child Template",  3 ]
  ]

  ASSOCIATION_TYPES_KEYS_BY_TOKEN = Hash[*ASSOCIATION_TYPES.map { |i| [i[0], i[2]] }.flatten]
  ASSOCIATION_TYPES_KEYS_BY_TYPE = Hash[*ASSOCIATION_TYPES.map { |i| [i[2], i[0]] }.flatten]

  before_validation :set_default_type, :validate_name
  before_destroy :reset_associated_templates, :unless => :general_template?
  after_save :destroy_attachments, :if => :child_template?

  #https://github.com/rails/rails/issues/988#issuecomment-31621550
  after_commit ->(obj) { obj.clear_template_count_cache }, on: :create, :unless => :child_template?
  after_commit ->(obj) { obj.clear_template_count_cache }, on: :destroy, :unless => :child_template?

  has_many_attachments

  has_many_cloud_files

  has_one :accessible,
    :class_name => 'Helpdesk::Access',
    :as         => 'accessible',
    :dependent  => :destroy

  has_many :shared_attachments,
    :as         => :shared_attachable,
    :class_name => '::Helpdesk::SharedAttachment',
    :dependent  => :destroy

  has_many :attachments_sharable,
    :through    => :shared_attachments,
    :source     => :attachment

  has_many :children,
    :class_name   => "Helpdesk::ParentChildTemplate",
    :foreign_key  => :parent_template_id,
    :dependent    => :destroy

  has_many :parents,
    :class_name   => "Helpdesk::ParentChildTemplate",
    :foreign_key  => :child_template_id,
    :dependent    => :destroy

  has_many :child_templates,
    :through => :children,
    :source  => :child_template

  has_many :parent_templates,
    :through => :parents,
    :source  => :parent_template

  has_many :groups,
           through: :accessible,
           source: :groups

  has_many :users,
           through: :accessible,
           source: :users

  serialize :template_data, Hash
  attr_accessor :reset_tmpl_assoc
  attr_accessible :name, :description, :template_data, :accessible_attributes, :parents_attributes, :children_attributes, :association_type
  xss_sanitize :only => [:name, :description, :data_description_html], :html_sanitize => [:name, :description], :decode_calm_sanitizer => [:data_description_html]

  accepts_nested_attributes_for :accessible
  accepts_nested_attributes_for :parents, :allow_destroy => true
  accepts_nested_attributes_for :children, :allow_destroy => true
  alias_attribute :helpdesk_accessible, :accessible
  delegate :visible_to_me?, :visible_to_only_me?, to: :accessible

  scope :shared_templates, ->(user) {
    where(%(acc.access_type!=%<users>s) % { :users => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]})
    .joins(%(JOIN helpdesk_accesses acc ON
                  acc.accessible_id = ticket_templates.id AND
                  acc.accessible_type = 'Helpdesk::TicketTemplate' AND
                  ticket_templates.account_id=%<account_id>i AND
                  acc.account_id = ticket_templates.account_id) % { :account_id => user.account_id })
  }

  scope :only_me, ->(user){
    where(%(acc.access_type=%<only_me>s and user_accesses.user_id=%<user_id>i ) % {
        :only_me => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
        :user_id => user.id})
    .joins(%(JOIN helpdesk_accesses acc ON
                  acc.accessible_id = ticket_templates.id AND
                  acc.accessible_type = 'Helpdesk::TicketTemplate' AND
                  ticket_templates.account_id=%<account_id>i AND
                  acc.account_id = ticket_templates.account_id
                  inner join user_accesses ON acc.id= user_accesses.access_id AND
                  acc.account_id= user_accesses.account_id) % { :account_id => user.account_id })
  }

  INCLUDE_ASSOCIATIONS_BY_CLASS = {
    Helpdesk::TicketTemplate => {:include => [{:accessible => [:group_accesses, :user_accesses]}]}
  }

  ASSOCIATION_TYPES_KEYS_BY_TOKEN.each do |key, value|
    define_method("#{key}_template?") do
      association_type.eql?(value)
    end
  end

  def to_indexed_json
   as_json({
     :root => "helpdesk/ticket_template",
     :tailored_json => true,
     :only => [:account_id, :name, :association_type],
     :methods => [:es_access_type, :es_group_accesses, :es_user_accesses],
     }).to_json
  end

  def to_count_es_json
    as_json({
    :root => false,
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

  def child_templates_count
    @child_count ||= self.children.count if parent_template?
  end

  def parent_templates_count
    @parent_count ||= self.parents.count if child_template?
  end

  def sanitize_template_data data_hash
    sanitize_hash_values data_hash
  end

  def build_parent_assn_attributes parent_id
    self.association_type = ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child] unless self.child_template?
    assn_id = (item_assn  = self.parents.where(:parent_template_id => parent_id).first) ?
      item_assn.id : item_assn
    self.parents_attributes = { :id => assn_id, :parent_template_id => parent_id, :_destroy => assn_id.present? }
  end

  def build_child_assn_attributes child_ids
    add_child_assn = []
    Account.current.child_templates.where(id: child_ids).find_each do |child|
      new_child = create_new_child(child)
      add_child_assn << { id: nil, child_template_id: new_child.id, _destroy: false } if new_child
    end
    if add_child_assn.present?
      self.association_type    = ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent]
      self.children_attributes = add_child_assn
    end
  end

  def retrieve_duplication(params, new_record)
    templ_ids = if params[:parent_id]
                  Account.current.ticket_templates.find(params[:parent_id]).child_templates.where(name: params[:name]).pluck(:id)
                else
                  Account.current.ticket_templates.shared_templates(User.current).where(name: params[:name]).pluck(:id)
                end
    templ_ids = templ_ids.select { |id| id != params[:id] } unless new_record
    templ_ids
  end

  def self.max_limit #this max limit is for general and parent templates only.
    Account.current.max_template_limit || TOTAL_SHARED_TEMPLATES
  end

  private

    def create_new_child(child)
      new_child = child.dup
      new_child.accessible = Account.current.accesses.new(access_type: accessible.access_type)
      new_child.accessible.groups = accessible.groups if accessible.access_type == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
      new_child.save!
      new_child
    rescue StandardError => e
      Rails.logger.debug "Create New Child Error::::: #{e}"
      false
    end

  def set_default_type
    if self.association_type.nil? || !Account.current.parent_child_tickets_enabled?
      self.association_type = ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general]
    end
  end

  def validate_name
    if !child_template? && !accessible.user_access_type? && (name_changed? || access_type_changed?)
      params = { name: name, id: id }
      templ_ids = retrieve_duplication(params, new_record?)
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
      next if (["description_html","email"].include?(key) || value.blank? || [true,false].include?(value))
      inputs_hash[key] = sanitize_value(value)
    end
  end

  def reset_associated_templates
    unless reset_tmpl_assoc
      item, assn_item_type = parent_template? ? [:parents, "child"] : [:children, "parent"]
      templates_ids = assn_templates(item, assn_item_type)
      Templates::CleanupWorker.perform_async({:templates_ids => templates_ids,
        :assn_item_type => assn_item_type}) if templates_ids.present?
    end
  end

  def destroy_attachments # only for child template
    if (data = self.template_data).present? && data.keys.include?("inherit_parent") &&
      (data["inherit_parent"] == "all" || data["inherit_parent"].include?("description_html"))
      ["attachments", "shared_attachments", "cloud_files"].each do |files|
        self.safe_send(files).destroy_all
      end
    end
  end

  def assn_templates item, assn_item_type
    assn_templ_ids =[]
    self.safe_send("#{assn_item_type}_templates").preload(item).map { |pt|
        assn_templ_ids << pt.id if pt.safe_send("#{item}").length <= 1 }
    assn_templ_ids
  end
end
