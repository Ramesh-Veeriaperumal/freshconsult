class Solution::Folder < ActiveRecord::Base

  self.primary_key = :id
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution
  include Solution::Activities

  concerned_with :associations

  attr_protected :category_id, :account_id
  validates_presence_of :name
  validates_uniqueness_of :language_id, :scope => [:account_id , :parent_id], :if => "!solution_folder_meta.new_record?"

  validate :name_uniqueness_validation, :if => "new_record? || name_changed?"

  self.table_name =  "solution_folders"

  before_save :backup_category
  before_destroy :backup_category

  after_commit :set_mobihelp_solution_updated_time, :if => Proc.new { |f| f.primary? }
  
  after_update :clear_cache, :if => Proc.new { |f| f.name_changed? && f.primary? }
  
  alias_method :parent, :solution_folder_meta
  
  scope :alphabetical, :order => 'name ASC'

  attr_accessible :name, :description, :category_id, :import_id, :visibility, :position, :is_default
  attr_accessor :count_articles

  delegate :visible?, :to => :solution_folder_meta
  delegate :visible_in?, :to => :solution_folder_meta

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

  def stripped_name
    (name || "").downcase.strip
  end

  def name_uniqueness_validation
    if ((self.solution_folder_meta.solution_category_meta.solution_folders.where(:language_id => self.language_id)) - [self]).map(&:stripped_name).include?(self.stripped_name)
      errors.add(:name, I18n.t("activerecord.errors.messages.taken"))
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

    def backup_category
      @category_obj = solution_category_meta
    end
    
    def set_mobihelp_solution_updated_time
      @category_obj.update_mh_solutions_category_time
    end
    
    def clear_cache
      Account.current.clear_solution_categories_from_cache
    end
end
