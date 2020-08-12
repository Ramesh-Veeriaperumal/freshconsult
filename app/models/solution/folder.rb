class Solution::Folder < ActiveRecord::Base

  self.primary_key = :id
  include Solution::Constants
  include Solution::Activities

  concerned_with :associations, :presenter

  publishable

  before_destroy :save_deleted_folder_info

  before_save :remove_emoji_in_folders

  validates_presence_of :name
  validates_uniqueness_of :language_id, :scope => [:account_id , :parent_id], :if => "!solution_folder_meta.new_record?"

  validate :name_uniqueness_validation, :if => "new_record? || name_changed?"

  self.table_name =  "solution_folders"
  
  after_commit ->(obj) { obj.safe_send(:clear_cache) }, on: :update
  
  alias_method :parent, :solution_folder_meta
  
  scope :alphabetical, -> { order('name ASC') }

  attr_accessible :name, :description, :import_id
  attr_accessor :count_articles

  delegate :visible?, :to => :solution_folder_meta
  delegate :visible_in?, :to => :solution_folder_meta
  
  # Hack to make sure JSON responses for Search API is proper.
  delegate :customer_folders, :to => :solution_folder_meta

  delegate :folder_visibility_mapping, to: :solution_folder_meta

  include Solution::LanguageMethods
  
  SELECT_ATTRIBUTES = ["id"]

  def to_s
    name
  end

  def self.folders_for_category category_id    
    self.find_by_category_id(category_id)    
  end
  
  def article_count
    self.count_articles ||= articles.size
  end

  def self.find_all_folders(account)
    self.where({ :account_id => account })
  end

  def self.account_folders(language_ids)
    joins(solution_folder_meta: :solution_category_meta).where('solution_category_meta.is_default = false AND solution_category_meta.account_id = ? AND solution_folders.language_id IN (?)', Account.current.id, language_ids)
  end

  def self.portal_folders(portal_id, language_ids)
    joins(solution_folder_meta: [solution_category_meta: :portal_solution_categories]).where('solution_category_meta.is_default = false AND solution_category_meta.account_id = ? AND portal_solution_categories.portal_id = ? AND solution_folders.language_id IN (?)', Account.current.id, portal_id, language_ids)
  end

  def self.folders_with_tags(tag_names)
    joins(solution_folder_meta: [tag_uses: :tags]).where('helpdesk_tags.account_id = ? AND helpdesk_tags.name in (?)', Account.current.id, tag_names)
  end

  def self.folders_with_platforms(platforms)
    platform_criteria = platforms.map { |platform_type| format('solution_platform_mappings.%{platform_type} = true', platform_type: platform_type) }.join(' OR ')
    joins(solution_folder_meta: :solution_platform_mapping).where(format('((%{platform_criteria}) AND solution_platform_mappings.account_id = %{account_id})', platform_criteria: platform_criteria, account_id: Account.current.id))
  end
  
  def to_xml(options = {})
     options[:root] = 'solution_folder'# TODO-RAILS3
     options[:indent] ||= 2
      xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id], :root => options[:root] ) 
  end

  def category_update_details
    return {} unless parent.previous_changes.key?(:solution_category_meta_id)

    { solution_category_name: parent.previous_changes[:solution_category_meta_id].map { |id| fetch_category_name(id) } }
  end

  def fetch_category_name(id)
    Account.current.solution_categories.where(parent_id: id, language_id: language_id).first.name
  end

  def as_json(options={})
    options[:except] = [:account_id,:import_id]
    super options
  end

  def primary?
    (language_id == Language.for_current_account.id)
  end

  def available?
    present?
  end

  def update_search_index
    SearchSidekiq::IndexUpdate::FolderArticles.perform_async({ :folder_id => id }) if Account.current.esv1_enabled?
    
    SearchV2::IndexOperations::UpdateArticleFolder.perform_async({ :folder_id => id }) if Account.current.features?(:es_v2_writes)
  end

  def stripped_name(name = self.name)
    (name || "").downcase.strip
  end

  def name_uniqueness_validation
    conditions = "`solution_folders`.`language_id` = #{self.language_id}"
    conditions << " AND `solution_folders`.`id` != #{self.id}" unless new_record?
    if self.solution_folder_meta.solution_category_meta.solution_folders.
            where(conditions).pluck(:name).map{|n| stripped_name(n)}.
            include?(self.stripped_name)
      errors.add(:name, :taken)
      return false
    end
    return true
  end

  def to_param
    parent_id
  end

  def save_deleted_folder_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end

  private

    def populate_account
      self.account = category.account
    end
    
    def remove_emoji_in_folders
      self.name = UnicodeSanitizer.remove_4byte_chars(self.name)
      self.description = UnicodeSanitizer.remove_4byte_chars(self.description)
    end
    
    def clear_cache
      Account.current.clear_solution_categories_from_cache if previous_changes['name'].present? && primary?
    end
end
