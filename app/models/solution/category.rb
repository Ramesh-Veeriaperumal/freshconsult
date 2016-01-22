# require Rails.root+'/app/models/solution/folder.rb'
#In the gamification environment, Solution::Folder::VISIBILITY_KEYS_BY_TOKEN was not
#accessible. It may be due to some screw up with the order of class loading.
#So, temporarily put the 'require' here. Shan

class Solution::Category < ActiveRecord::Base

  self.primary_key = :id
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution
  include Mobihelp::AppSolutionsUtils
  include Solution::MetaMethods

  CACHEABLE_ATTRS = ["id","name","account_id","position","is_default"]

  self.table_name =  "solution_categories"

  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id, :case_sensitive => false

  after_create :clear_cache, :add_activity_new
  after_destroy :clear_cache
  after_update :clear_cache_with_condition

  after_save    :set_mobihelp_solution_updated_time
  before_destroy :set_mobihelp_app_updated_time, :add_activity_delete

  concerned_with :associations

  before_create :set_default_portal

  attr_accessible :name, :description, :import_id, :is_default, :portal_ids, :position

  acts_as_list :scope => :account

  scope :customer_categories, {:conditions => {:is_default=>false}}

  include Solution::LanguageMethods

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

  def to_liquid
    @solution_category_drop ||= (Solution::CategoryDrop.new self)
  end

  def as_cache
    (CACHEABLE_ATTRS.inject({}) do |res, attribute|
      res.merge({ attribute => self.send(attribute) })
    end).with_indifferent_access
  end

  private

    def set_mobihelp_solution_updated_time
      self.update_mh_solutions_category_time
    end

    def set_mobihelp_app_updated_time
      self.update_mh_app_time
    end

    def add_activity_delete
      create_activity('delete_solution_category')
    end

    def add_activity_new
      create_activity('new_solution_category')
    end
  
    def create_activity(type)
      activities.create(
        :description => "activities.solutions.#{type}.long",
        :short_descr => "activities.solutions.#{type}.short",
        :account    => account,
        :user       => User.current,
        :activity_data  => {
                    :path => Rails.application.routes.url_helpers.solution_category_path(self),
                    :url_params => {
                              :id => id,
                              :path_generator => 'solution_category_path'
                            },
                    :title => name.to_s
                  }
      )
    end

    def clear_cache(obj=nil)
      account.clear_solution_categories_from_cache
    end

    def clear_cache_with_condition
      account.clear_solution_categories_from_cache if self.name_changed?
    end


    ### MULTILINGUAL SOLUTIONS - META WRITE HACK!!
    def set_default_portal
      self.portal_ids = [Account.current.main_portal.id] if self.portal_ids.blank?
    end

end
