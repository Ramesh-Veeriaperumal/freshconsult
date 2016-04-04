class Solution::FolderMeta < ActiveRecord::Base

	self.primary_key = :id

	self.table_name = "solution_folder_meta"
  include Solution::Constants
	include Solution::LanguageAssociations
	include Solution::ApiDelegator
	belongs_to_account

  validates_inclusion_of :visibility,
      :in => VISIBILITY_KEYS_BY_TOKEN.values.min..VISIBILITY_KEYS_BY_TOKEN.values.max

	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta'

	has_many :solution_folders, :class_name => "Solution::Folder", :foreign_key => "parent_id", :autosave => true

	has_many :customer_folders , :class_name => 'Solution::CustomerFolder' , :dependent => :destroy

	has_many :customers, :through => :customer_folders, :class_name => 'Solution::CustomerFolder'

	has_many :solution_article_meta,
		:class_name => "Solution::ArticleMeta",
		:foreign_key => :solution_folder_meta_id,
		:order => :"solution_article_meta.position"

	has_many :solution_articles,
		:class_name => "Solution::Article",
		:through => :solution_article_meta,
		:order => :"solution_article_meta.position"
		
	has_many :published_article_meta, 
		:class_name =>'Solution::ArticleMeta',
		:foreign_key => :solution_folder_meta_id, 
		:order => "`solution_article_meta`.position",
 		:conditions => "`solution_articles`.status = 
			#{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]}"

	COMMON_ATTRIBUTES = ["visibility", "position", "is_default", "created_at"]

	scope :visible, lambda {|user|
		{
			:order => "`solution_folder_meta`.position",
			:conditions => visibility_condition(user)
		}
	}

	def self.visibility_condition(user)
		condition = "`solution_folder_meta`.visibility IN (#{ self.get_visibility_array(user).join(',') })"
		condition +=  "OR (`solution_folder_meta`.visibility=#{VISIBILITY_KEYS_BY_TOKEN[:company_users]} " <<
				"AND `solution_folder_meta`.id in (SELECT solution_customer_folders.folder_meta_id " <<
				"FROM solution_customer_folders " <<
				"WHERE solution_customer_folders.customer_id = #{user.company_id} " <<
				"AND solution_customer_folders.account_id = #{user.account_id}))" if (user && user.has_company?)
					# solution_customer_folders.customer_id = #{ user.company_id})" if (user && user.has_company?)
		return condition
	end

	def self.get_visibility_array(user)
		if user && user.privilege?(:manage_tickets)
		  VISIBILITY_NAMES_BY_KEY.keys
		elsif user
		  [VISIBILITY_KEYS_BY_TOKEN[:anyone],VISIBILITY_KEYS_BY_TOKEN[:logged_users]]
		else
		  [VISIBILITY_KEYS_BY_TOKEN[:anyone]]
		end
	end

	def visible?(user)
	  return true if (user and user.privilege?(:view_solutions))
	  return true if self.visibility == VISIBILITY_KEYS_BY_TOKEN[:anyone]
	  return true if (user and (self.visibility == VISIBILITY_KEYS_BY_TOKEN[:logged_users]))
	  return true if (user && (self.visibility == VISIBILITY_KEYS_BY_TOKEN[:company_users]) && user.company  && customer_folders.map(&:customer_id).include?(user.company.id))
	end

	def visible_in? portal
	  solution_category_meta.portal_ids.include?(portal.id)
	end

	def to_liquid
		@solution_folder_meta_drop ||= (Solution::FolderMetaDrop.new self)
	end
end
