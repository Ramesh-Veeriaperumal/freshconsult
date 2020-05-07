class Solution::CategoryMeta < ActiveRecord::Base

	self.primary_key = :id
	self.table_name = 'solution_category_meta'

	BINARIZE_COLUMNS = [:available]

	include Solution::LanguageAssociations
	include Solution::Constants
	include Solution::ApiDelegator
	include Solution::MarshalDumpMethods

	attr_accessible :position, :portal_ids, :portal_solution_categories_attributes

	belongs_to_account

	has_many :solution_folders, :through => :solution_folder_meta

	has_many :solution_categories, 
		:inverse_of => :solution_category_meta, 
		:class_name => "Solution::Category", 
		:foreign_key => "parent_id", 
		:autosave => true, 
		:dependent => :destroy

	has_many :solution_article_meta, 
		:through => :solution_folder_meta,
		:class_name => "Solution::ArticleMeta"

	has_many :portal_solution_categories, 
		:class_name => 'PortalSolutionCategory',
		:foreign_key => :solution_category_meta_id,
		:dependent => :destroy

  has_many :help_widget_solution_categories,
           class_name: 'HelpWidgetSolutionCategory',
           dependent: :destroy,
           foreign_key: :solution_category_meta_id,
           inverse_of: :solution_category_meta

  has_many :portals,
		:through => :portal_solution_categories,
		:class_name => "Portal",
    :after_add => :clear_cache,
    :after_remove => :clear_cache

	has_many :solution_folder_meta, 
		:class_name => "Solution::FolderMeta", 
		:foreign_key => :solution_category_meta_id, 
		:order => "`solution_folder_meta`.solution_category_meta_id, `solution_folder_meta`.position"

	has_many :public_folder_meta,
		:conditions => ["`solution_folder_meta`.visibility = ? ",VISIBILITY_KEYS_BY_TOKEN[:anyone]],
		:order => "`solution_folder_meta`.position",
		:class_name =>'Solution::FolderMeta',
		:foreign_key => :solution_category_meta_id
		

	COMMON_ATTRIBUTES = ["position", "is_default", "created_at"]
	CACHEABLE_ATTRIBUTES = ["id","name","account_id","position","is_default"]
	PORTAL_CACHEABLE_ATTRIBUTES = ["id", "account_id", "current_child_id", "name", "description"]

	before_create :set_default_portal
	before_save :validate_is_default
	after_destroy :delete_folder_meta

  	after_commit ->(obj) { obj.safe_send(:clear_cache) }, on: :create
  	after_commit ->(obj) { obj.safe_send(:clear_cache) }, on: :destroy

	alias_method :children, :solution_categories
	
	scope :customer_categories, {:conditions => {:is_default=>false}}

	def as_cache
	  (CACHEABLE_ATTRIBUTES.inject({}) do |res, attribute|
	    res.merge({ attribute => self.safe_send(attribute) })
	  end).with_indifferent_access
	end
	
	def to_liquid
		@solution_category_drop ||= (Solution::CategoryDrop.new self)
	end

	def visible_folders_count
		@visible_folders_count ||= solution_folder_meta.visible(User.current).count
	end

	def visible_folders
		@visible_folders ||= ((visible_folders_count > 0) ? 
				solution_folder_meta.visible(User.current).all : [])
	end

  def portal_solution_categories_attributes=(portal_attr)
    portal_solution_categories.destroy_all
    portal_attr[:portal_id].each do |portal_id|
      portal_solution_categories.build(portal_id: portal_id)
    end
  end

	private
	
		def delete_folder_meta
	  	Rails.logger.debug "Adding delete category_meta job for category_id #{id}"
	  	DeleteSolutionMetaWorker.perform_async(parent_level_id: id, object_type: 'category_meta')
		end

	def clear_cache(args = nil)
		Account.current.clear_solution_categories_from_cache
	end

	def set_default_portal
	  self.portal_ids = [Account.current.main_portal.id] if self.portal_ids.blank? && self.portal_solution_categories.blank?
	end

  def validate_is_default
    if changes[:is_default].present? || (new_record? && is_default)
      default_category = Account.current.solution_category_meta.where(:is_default => true).first
      return true unless default_category.present?
      self.is_default = default_category.id == id
    end
  end

	def custom_portal_cache_attributes
		{
			:visible_folders_count => visible_folders_count,
			:visible_folders => visible_folders
		}
	end

	def portal_ids=(ids)
		@model_changes = { portal_ids: [self.portal_ids, ids.map(&:to_i)]}
		super
	end

  def self.bot_articles_count_hash(category_ids)
    count_hash = {}
    result = Sharding.run_on_slave { ActiveRecord::Base.connection.execute(bot_articles_count_query(category_ids)) }
    result.each do |category_id, articles_count|
      count_hash[category_id] = articles_count
    end
    count_hash
  end

  def self.bot_articles_count_query(category_ids)
    "SELECT
      `solution_category_meta`.`id`,
      COUNT(`solution_article_meta`.`id`)
    FROM
      `solution_category_meta`
      INNER JOIN `solution_folder_meta` ON `solution_folder_meta`.`solution_category_meta_id` = `solution_category_meta`.`id`
        AND `solution_folder_meta`.`account_id` = `solution_category_meta`.`account_id`
      INNER JOIN `solution_article_meta` ON `solution_article_meta`.`solution_folder_meta_id` = `solution_folder_meta`.`id`
        AND `solution_article_meta`.`account_id` = `solution_folder_meta`.`account_id`
      INNER JOIN `solution_articles` ON `solution_articles`.`parent_id` = `solution_article_meta`.`id`
        AND `solution_articles`.`language_id` = #{Language.current.id}
        AND `solution_articles`.`account_id` = `solution_article_meta`.`account_id`
      WHERE
        (`solution_articles`.`status` = #{Solution::Constants::STATUS_KEYS_BY_TOKEN[:published]})
        AND (
          `solution_folder_meta`.`visibility` IN (#{Solution::Constants::BOT_VISIBILITIES.join(',')})
        )
        AND (
          `solution_category_meta`.`id` IN (#{category_ids.join(',')}))
        AND `solution_category_meta`.`account_id` = #{Account.current.id}
    GROUP BY
      `solution_category_meta`.`id`"
  end
end
