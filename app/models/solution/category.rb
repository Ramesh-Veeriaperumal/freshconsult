class Solution::Category < ActiveRecord::Base

  self.primary_key = :id
  include Solution::Constants
  include Solution::Activities

  concerned_with :presenter

  publishable

  before_destroy :save_deleted_category_info

  before_save :remove_emoji_in_categories

  belongs_to_account

  belongs_to :solution_category_meta, 
    :class_name => 'Solution::CategoryMeta', 
    :foreign_key => "parent_id"

  has_many :solution_folder_meta,
    :through => :solution_category_meta,
    :class_name => 'Solution::FolderMeta',
    :foreign_key => :solution_category_meta_id

  has_many :activities,
    :class_name => 'Helpdesk::Activity',
    :as => 'notable'

  self.table_name =  "solution_categories"

  validates_presence_of :name,:account
  validate :name_uniqueness_validation
  validates_uniqueness_of :language_id, :scope => [:account_id , :parent_id], :if => "!solution_category_meta.new_record?"
  
  after_commit ->(obj) { obj.safe_send(:clear_cache) }, on: :update

  attr_accessible :name, :description, :import_id

  scope :customer_categories, -> { where(is_default: false) }

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

  def stripped_name(name = self.name)
    (name || "").downcase.strip
  end

  def save_deleted_category_info
    @deleted_model_info = as_api_response(:central_publish_destroy) 
  end
   
  private
  
    def name_uniqueness_validation
      return true unless new_record? || name_changed?
      conditions = "`solution_categories`.`language_id` = #{self.language_id}"
      conditions << " AND `solution_categories`.`id` != #{self.id}" unless new_record?
      if Account.current.solution_categories.
            where(conditions).pluck(:name).map{|n| stripped_name(n)}.
            include?(self.stripped_name)
        errors.add(:name, :taken)
        return false
      end
      return true
    end

    def remove_emoji_in_categories
      self.name = UnicodeSanitizer.remove_4byte_chars(self.name)
      self.description = UnicodeSanitizer.remove_4byte_chars(self.description)
    end

    def clear_cache(obj=nil)
      Account.current.clear_solution_categories_from_cache if previous_changes['name'].present? && primary?
    end
end
