class Solution::FolderMeta < ActiveRecord::Base

	self.primary_key = :id

	self.table_name = "solution_folder_meta"

	BINARIZE_COLUMNS = [:available]
	
    include Solution::Constants
	include Solution::LanguageAssociations
	include Solution::ApiDelegator
	include Solution::MarshalDumpMethods
    include Helpdesk::TagMethods
    include SolutionHelper
    include CloudFilesHelper
	
  attr_accessible :visibility, :position, :solution_category_meta_id

	belongs_to_account

  validates_inclusion_of :visibility, 
      :in => VISIBILITY_KEYS_BY_TOKEN.values.min..VISIBILITY_KEYS_BY_TOKEN.values.max

  validate :name_uniqueness, :if => "changes[:solution_category_meta_id]" 

	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta', :autosave => true

	has_many :solution_folders, 
		:inverse_of => :solution_folder_meta,
		:class_name => "Solution::Folder", 
		:foreign_key => "parent_id", 
		:autosave => true, 
		:dependent => :destroy

	has_many :customer_folders , 
		:class_name => 'Solution::CustomerFolder' , 
		:autosave => true,
		:dependent => :destroy

	has_many :customers, :through => :customer_folders

  has_many :folder_visibility_mapping,
    class_name: 'Solution::FolderVisibilityMapping',
    autosave: true,
    dependent: :destroy

  has_one :icon,
    as: :attachable,
    class_name: 'Helpdesk::Attachment',
    dependent: :destroy

  has_one :solution_platform_mapping,
    as: :mappable,
    class_name: 'SolutionPlatformMapping',
    autosave: true,
    dependent: :destroy

  has_many :tag_uses,
    class_name: 'Helpdesk::TagUse',
    as: :taggable,
    dependent: :destroy

  has_many :tags,
    class_name: 'Helpdesk::Tag',
    through: :tag_uses

  has_many :contact_filters,
    class_name: 'ContactFilter',
    source: :mappable,
    source_type: 'ContactFilter',
    through: :folder_visibility_mapping

  has_many :company_filters,
    class_name: 'CompanyFilter',
    source: :mappable,
    source_type: 'CompanyFilter',
    through: :folder_visibility_mapping

	has_many :solution_article_meta,
		:order => :"solution_article_meta.position",
		:class_name => "Solution::ArticleMeta",
		:foreign_key => :solution_folder_meta_id

	has_many :solution_articles,
		:through => :solution_article_meta,
		:order => :"solution_article_meta.position",
		:class_name => "Solution::Article"
		
	has_many :published_article_meta, 
 		:conditions => "`solution_articles`.status = 
			#{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]}",
		:order => "`solution_article_meta`.position",
		:class_name =>'Solution::ArticleMeta',
		:foreign_key => :solution_folder_meta_id

	has_many :published_articles,
		:conditions => proc {%{`solution_articles`.status = 
			#{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]} AND 
			`solution_articles`.language_id = #{Language.for_current_account.id}} },
		:through => :solution_article_meta,
		:class_name => "Solution::Article",
		:source => :solution_articles


	acts_as_list :scope => :solution_category_meta

	COMMON_ATTRIBUTES = ["visibility", "position", "is_default", "created_at"]
	CACHEABLE_ATTRIBUTES  = ["is_default","name","id","article_count"]
	PORTAL_CACHEABLE_ATTRIBUTES = ["id", "account_id", "current_child_id", "name", "description",
	 "visibility", "solution_category_meta_id"]

    before_update :clear_customer_folders, :backup_folder_changes, :clear_segment_folders, :clear_platforms_and_tags
	after_commit :update_search_index, on: :update, :if => :update_es?
  
  after_commit ->(obj) { obj.safe_send(:clear_cache) }, on: :create
  after_commit ->(obj) { obj.safe_send(:clear_cache) }, on: :destroy
  after_commit ->(obj) { obj.safe_send(:clear_cache_with_condition) }, on: :update

	before_save :backup_category
	before_destroy :backup_category
	after_destroy :delete_article_meta
	validate :companies_limit_check
    after_commit :update_article_platform_mapping, on: :update, if: :update_article_platform_mapping?

  after_commit :kb_service_clear_cache, on: :update, if: :platforms_tags_updated?
	alias_method :children, :solution_folders

	def article_count
	  solution_article_meta.size
	end

	def as_cache
	  (CACHEABLE_ATTRIBUTES.inject({}) do |res, attribute|
	    res.merge({ attribute => self.safe_send(attribute) })
	  end).with_indifferent_access
	end

	def visibility_type
		translated_visibility_name_by_key[self.visibility]
	end

  def customer_folders_attributes=(cust_attr)
    return if cust_attr.nil?
    customer_folders.destroy_all
    company_ids = cust_attr.kind_of?(Array) ? cust_attr : cust_attr[:customer_id]
    company_ids.each do |cust_id|
      customer_folders.build({:customer_id =>cust_id})
    end
  end

  def contact_folders_attributes=(contact_ids)
    return if contact_ids.nil?
    folder_visibility_mapping.destroy_all
    contact_ids.each do |contact_filter_id|
      folder_visibility_mapping.build({ mappable_id: contact_filter_id, mappable_type: 'ContactFilter' })
    end
  end

  def company_folders_attributes=(company_ids)
    return if company_ids.nil?
    folder_visibility_mapping.destroy_all
    company_ids.each do |company_filter_id|
      folder_visibility_mapping.build({ mappable_id: company_filter_id, mappable_type: 'CompanyFilter' })
    end
  end

  def icon_attribute=(folder_icon)
    if folder_icon.blank?
      return if icon.blank?

      icon.destroy
    else
      build_normal_attachments(self, nil, folder_icon)
    end
  end

  def platforms=(platform_params)
    return if platform_params.empty?

    @platforms_updated = true
    solution_platform_mapping.present? ? update_platform_mapping(platform_params) : create_platform_mapping(platform_params)
  end

  def update_platform_mapping(platform_params)
    if any_platforms_enabled?(self, platform_params)
      solution_platform_mapping.update_attributes(platform_params)
      @disabled_platforms = platform_params.select { |platform, enabled| !enabled }
      @platform_updated = true
    else
      solution_platform_mapping.destroy
      tag_uses.destroy tag_uses
      @platform_mapping_destroyed = true
    end
  end

  def create_platform_mapping(platform_params)
    build_solution_platform_mapping(platform_params) if SolutionPlatformMapping.any_platform_enabled?(platform_params)
  end

  def tag_attributes=(tag_array)
    return if tag_array.nil?

    if solution_platform_mapping.present? && !solution_platform_mapping.try(:destroyed?)
      tag_objects = construct_tags(tag_array)
      if array_of_tag_objects?(tag_objects)
        @tags_updated = !(tag_objects - self.tags).empty? || !(self.tags - tag_objects).empty?
        self.tags = tag_objects
      end
    end
  end

  def array_of_tag_objects?(tags)
    return false unless tags && tags.is_a?(Array)

    tags.all? { |tag| tag.is_a?(Helpdesk::Tag) }
  end

	def add_visibility(visibility, customer_ids, add_to_existing)
    ActiveRecord::Base.transaction do
      add_companies(customer_ids, add_to_existing) if visibility == Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:company_users]
      self.visibility = visibility
      save
      primary_folder.save # Dummy save to trigger publishable callbacks
    end
  end

  def has_company_visiblity?
    visibility == VISIBILITY_KEYS_BY_TOKEN[:company_users]
  end

  def visible_to_bot?
    BOT_VISIBILITIES.include?(visibility)
  end

	def to_liquid
		@solution_folder_drop ||= Solution::FolderDrop.new self
	end

	def update_search_index
	  SearchSidekiq::IndexUpdate::FolderArticles.perform_async({ :folder_id => id }) if Account.current.esv1_enabled?

	  SearchV2::IndexOperations::UpdateArticleFolder.perform_async({ :folder_id => id }) if Account.current.features_included?(:es_v2_writes)
	end

	def clear_customer_folders
	  customer_folders.destroy_all if (visibility_changed? and visibility_was == VISIBILITY_KEYS_BY_TOKEN[:company_users])
	end

  def clear_segment_folders
    folder_visibility_mapping.where(mappable_type: 'ContactFilter').destroy_all if visibility_changed? && visibility_was == VISIBILITY_KEYS_BY_TOKEN[:contact_segment]
    folder_visibility_mapping.where(mappable_type: 'CompanyFilter').destroy_all if visibility_changed? && visibility_was == VISIBILITY_KEYS_BY_TOKEN[:company_segment]
  end

  def clear_platforms_and_tags
    if visibility_changed? && visibility_was == VISIBILITY_KEYS_BY_TOKEN[:anyone]
      if solution_platform_mapping.present?
        solution_platform_mapping.destroy
        @platform_mapping_destroyed = true
      end
      tag_uses.destroy tag_uses if tag_uses.present?
    end
  end
  
	def visible?(user)
	  return true if (user and user.privilege?(:view_solutions))
	  return true if self.visibility == VISIBILITY_KEYS_BY_TOKEN[:anyone]
	  return false unless user
	  return true if self.visibility == VISIBILITY_KEYS_BY_TOKEN[:logged_users]
      company_cdn = !customer_folders.where(customer_id: user.company_ids).empty?
	  return true if (self.visibility == VISIBILITY_KEYS_BY_TOKEN[:company_users]) && company_cdn

      contact_filter_cdn = !folder_visibility_mapping.where(mappable_type: 'ContactFilter', mappable_id: user.segments).empty?
	  return true if (self.visibility == VISIBILITY_KEYS_BY_TOKEN[:contact_segment]) && contact_filter_cdn

      company_filter_cdn = !folder_visibility_mapping.where(mappable_type: 'CompanyFilter', mappable_id: user.company_segment_ids).empty?
      return true if (self.visibility == VISIBILITY_KEYS_BY_TOKEN[:company_segment]) && company_filter_cdn
	end

	def visible_articles_count
		@visible_articles_count ||= published_article_meta.count
	end

	def visible_articles
		@visible_articles ||= ((visible_articles_count > 0) ? sorted_published_article_meta.all : [])
	end

 	def sorted_solution_article_meta
   		@sorted_solution_article_meta ||= (Language.current? ? solution_article_meta.reorder(Solution::Constants::ARTICLE_ORDER_COLUMN_BY_TYPE[article_order]) : solution_article_meta)
 	end
 
	def sorted_solution_articles
		@sorted_solution_atricles ||= (Language.current? ? solution_articles.reorder(Solution::Constants::ARTICLE_ORDER_COLUMN_BY_TYPE[article_order]) : solution_articles)
	end
 
	def sorted_published_article_meta
		@sorted_published_article_meta ||= (Language.current? ? published_article_meta.reorder(Solution::Constants::ARTICLE_ORDER_COLUMN_BY_TYPE[article_order]) : published_article_meta)
	end 

	def add_companies(customer_ids, add_to_existing)
	    customer_folders.destroy_all unless add_to_existing
	    customer_ids.each do |cust_id|
	      customer_folders.build({:customer_id => cust_id}) unless self.customer_ids.include?(cust_id)
	    end
	end

    def add_contact_filters(contact_segment_ids, add_to_existing)
      folder_visibility_mapping.destroy_all unless add_to_existing
      filtered_contact_segment_ids = contact_segment_ids - folder_visibility_mapping.where('mappable_id IN (?) and mappable_type = ?', contact_segment_ids, 'ContactFilter').pluck(:mappable_id)
      filtered_contact_segment_ids.each do |contact_segment_id|
        folder_visibility_mapping.build({ mappable_id: contact_segment_id, mappable_type: 'ContactFilter' })
      end
    end

    def add_company_filters(company_segment_ids, add_to_existing)
      folder_visibility_mapping.destroy_all unless add_to_existing
      filtered_company_segment_ids = company_segment_ids - folder_visibility_mapping.where('mappable_id IN (?) and mappable_type = ?', company_segment_ids, 'CompanyFilter').pluck(:mappable_id)
      filtered_company_segment_ids.each do |company_segment_id|
        folder_visibility_mapping.build({ mappable_id: company_segment_id, mappable_type: 'CompanyFilter' })
      end
    end

  def article_order
    Account.current.auto_article_order_enabled? ? self[:article_order] : Solution::Constants::ARTICLE_ORDER_KEYS_TOKEN[:custom]
  end

	private

    def platforms_tags_updated?
      @platforms_updated == true || @tags_updated == true
    end

    def kb_service_clear_cache
      job_id = Solution::KbserviceClearCacheWorker.perform_async(entity: 'folder')
      Rails.logger.info "KBServiceClearCache:: folder_update, #{job_id}"
    end

		def delete_article_meta
	  	Rails.logger.debug "Adding delete article_meta job for folder_meta_id: #{id}"
	  	DeleteSolutionMetaWorker.perform_async(parent_level_id: id, object_type: 'folder_meta')
		end

        def update_article_platform_mapping
          Rails.logger.debug "Adding edit article_platform_mapping job for folder_meta_id: #{id}"
          if @platform_mapping_destroyed
            UpdateArticlePlatformMappingWorker.perform_async(parent_level_id: id, object_type: 'folder_meta')
          elsif @disabled_platforms
            UpdateArticlePlatformMappingWorker.perform_async(parent_level_id: id, object_type: 'folder_meta', disabled_folder_platforms: @disabled_platforms)
          end
        end

	def clear_cache
		Account.current.clear_solution_categories_from_cache
	end

	def clear_cache_with_condition
		clear_cache unless (previous_changes.keys & ['solution_category_meta_id', 'position']).empty?
	end

  def name_uniqueness
    solution_folders.each do |folder|
      # inverse_of doesn't work in language association
      # We need to check against new name for validation if modified.New value will be available only in language association.
      language_key = Language.for_current_account.id == folder.language_id ? 'primary' : Language.find(folder.language.id).to_key
      child_assoc = "#{language_key}_folder".to_sym
      folder = safe_send(child_assoc) if association_cache[child_assoc].present?
      folder.name_uniqueness_validation
      if folder.errors[:name].any?
        errors.add(:name, I18n.t('activerecord.errors.messages.taken'))
        break
      end
    end
  end

	def companies_limit_check
		if customer_folders.size > COMPANIES_LIMIT
		  errors.add(:base, I18n.t("solution.folders.visibility.companies_limit_exceeded"))
		  return false
		else
		  return true
		end
	end

  scope :visible, -> (user) {
    where(visibility_condition(user)).
    order("`solution_folder_meta`.position")
  }

	scope :public_folders, -> (category_ids) {
		where(
			solution_category_meta_id: category_ids,
			visibility: VISIBILITY_KEYS_BY_TOKEN[:anyone]
		)	
	}

	def self.visibility_condition(user)
		condition = "`solution_folder_meta`.visibility IN (#{ self.get_visibility_array(user).join(',') })"
		if (user && user.has_company?)
			condition +=  "OR (`solution_folder_meta`.visibility=#{VISIBILITY_KEYS_BY_TOKEN[:company_users]} " <<
					"AND `solution_folder_meta`.id in (SELECT solution_customer_folders.folder_meta_id " <<
					"FROM solution_customer_folders " <<
					"WHERE solution_customer_folders.customer_id in (#{user.company_ids_str}) " <<
					"AND solution_customer_folders.account_id = #{user.account_id}))"
		end
					# solution_customer_folders.customer_id = #{ user.company_id})" if (user && user.has_company?)
		if (user && user.has_company_segment?)		  
		  condition += "OR (`solution_folder_meta`.visibility=#{VISIBILITY_KEYS_BY_TOKEN[:company_segment]} " <<
					"AND `solution_folder_meta`.id in (SELECT folder_visibility_mapping.folder_meta_id " <<
					"FROM folder_visibility_mapping " <<
					"WHERE folder_visibility_mapping.mappable_id in (#{user.company_segment_ids_str}) " <<
					"AND folder_visibility_mapping.account_id = #{user.account_id} " <<
					"AND `folder_visibility_mapping`.mappable_type='CompanyFilter'))"
		end
		if (user && user.has_contact_segment?)
			condition += "OR (`solution_folder_meta`.visibility=#{VISIBILITY_KEYS_BY_TOKEN[:contact_segment]} " <<
					  "AND `solution_folder_meta`.id in (SELECT folder_visibility_mapping.folder_meta_id " <<
					  "FROM folder_visibility_mapping " <<
					  "WHERE folder_visibility_mapping.mappable_id in (#{user.contact_segment_ids_str}) " <<
					  "AND folder_visibility_mapping.account_id = #{user.account_id} " <<
					  "AND `folder_visibility_mapping`.mappable_type='ContactFilter'))"
		end
		return condition
	end

	def self.get_visibility_array(user)
		if user && user.privilege?(:manage_tickets)
		  VISIBILITY_NAMES_BY_KEY.keys - [Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:bot]]
		elsif user
		  [VISIBILITY_KEYS_BY_TOKEN[:anyone],VISIBILITY_KEYS_BY_TOKEN[:logged_users]]
		else
		  [VISIBILITY_KEYS_BY_TOKEN[:anyone]]
		end
	end

	def visible_in? portal
	  visibility != Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:bot] && solution_category_meta.portal_ids.include?(portal.id)
	end

	def backup_folder_changes
	  @companies_updated = self.customer_folders.any? { |a| a.changed? }
	  @segments_updated = self.folder_visibility_mapping.any? { |a| a.changed? }
	  @all_changes = self.changes.clone
	end

	def update_es?
	  (@all_changes.keys & ['visibility', 'solution_category_meta_id']).present? || @companies_updated || @segments_updated
	end

    def update_article_platform_mapping?
      @disabled_platforms.present? || @platform_mapping_destroyed
    end

	def backup_category
		@category_obj = solution_category_meta
	end

	def custom_portal_cache_attributes
		{
			:visible_articles_count => visible_articles_count,
			:visible_articles => visible_articles
		}
	end
end
