class Solution::Folder < ActiveRecord::Base

  self.primary_key = :id
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution
  include Solution::Activities

  concerned_with :associations

  validates_presence_of :name
  validates_uniqueness_of :language_id, :scope => [:account_id , :parent_id], :if => "!solution_folder_meta.new_record?"

  validate :name_uniqueness_validation, :if => "new_record? || name_changed?"

  self.table_name =  "solution_folders"
  
  after_commit ->(obj) { obj.send(:clear_cache) }, on: :update
  
  alias_method :parent, :solution_folder_meta
  
  scope :alphabetical, :order => 'name ASC'

  attr_accessible :name, :description, :import_id
  attr_accessor :count_articles

  delegate :visible?, :to => :solution_folder_meta
  delegate :visible_in?, :to => :solution_folder_meta
  
  # Hack to make sure JSON responses for Search API is proper.
  delegate :customer_folders, :to => :solution_folder_meta

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
  
  def to_xml(options = {})
     options[:root] = 'solution_folder'# TODO-RAILS3
     options[:indent] ||= 2
      xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id], :root => options[:root] ) 
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
    SearchSidekiq::IndexUpdate::FolderArticles.perform_async({ :folder_id => id }) if ES_ENABLED
    
    SearchV2::IndexOperations::UpdateArticleFolder.perform_async({ :folder_id => id }) if Account.current.features_included?(:es_v2_writes)
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

  private

    def populate_account
      self.account = category.account
    end
    
    def clear_cache
      Account.current.clear_solution_categories_from_cache if previous_changes['name'].present? && primary?
    end
end
