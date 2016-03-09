# require Rails.root+'/app/models/solution/folder.rb'
#In the gamification environment, Solution::Folder::VISIBILITY_KEYS_BY_TOKEN was not
#accessible. It may be due to some screw up with the order of class loading.
#So, temporarily put the 'require' here. Shan

class Solution::Category < ActiveRecord::Base

  self.primary_key = :id
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution
  include Mobihelp::AppSolutionsUtils
  include Solution::Activities

  self.table_name =  "solution_categories"

  validates_presence_of :name,:account
  validate :name_uniqueness_validation
  validates_uniqueness_of :language_id, :scope => [:account_id , :parent_id], :if => "!solution_category_meta.new_record?"
  
  after_update :clear_cache, :if => Proc.new { |c| c.name_changed? && c.primary? }
  after_save    :set_mobihelp_solution_updated_time, :if => Proc.new { |c| c.primary? }
  before_destroy :set_mobihelp_app_updated_time, :if => Proc.new { |c| c.primary? }

  concerned_with :associations

  attr_accessible :name, :description, :import_id, :is_default, :portal_ids, :position

  scope :customer_categories, {:conditions => {:is_default=>false}}

  alias_method :parent, :solution_category_meta

  include Solution::LanguageMethods
  
  SELECT_ATTRIBUTES = ["id"]

  def to_s
    name
  end

  def to_xml(options = {})
     options[:root] ||= 'solution_category'
     options[:indent] ||= 2
      xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id], :root => options[:root])
  end

  def as_json(options={})
    options[:except] = [:account_id,:import_id]
    super options
  end

  def self.folder_names(account)
    account.solution_categories.map { |category|
      [ category.name, category.folders.map {|folder| [folder.id, folder.name] } ]
    }
  end

  def self.get_default_categories_visibility(user)
    user.customer? ? {:is_default=>false} : {}
  end

  def primary?
    (language_id == Language.for_current_account.id)
  end

  def available?
    present?
  end

  def to_param
    parent_id
  end

  def stripped_name
    (name || "").downcase.strip
  end
   
  private
  
    def name_uniqueness_validation
      return true unless new_record? || name_changed?
      if (Account.current.solution_categories.where(:language_id => self.language_id) - [self]).map(&:stripped_name).include?(self.stripped_name)
        errors.add(:name, I18n.t("activerecord.errors.messages.taken"))
        return false
      end
      return true
    end

    def set_mobihelp_solution_updated_time
      self.update_mh_solutions_category_time
    end

    def set_mobihelp_app_updated_time
      self.update_mh_app_time
    end

    def clear_cache(obj=nil)
      Account.current.clear_solution_categories_from_cache
    end
end
