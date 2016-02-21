# encoding: utf-8
class Solution::Article < ActiveRecord::Base
  self.primary_key= :id
  self.table_name =  "solution_articles"
  belongs_to_account
  concerned_with :associations, :body_methods, :esv2_methods
  
  include Juixe::Acts::Voteable
  include Search::ElasticSearchIndex

  include Solution::MetaMethods

  belongs_to :recent_author, :class_name => 'User', :foreign_key => "modified_by"
  has_one :draft, :dependent => :destroy

  include Solution::LanguageMethods
  
  include Mobile::Actions::Article
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution
  
  include Community::HitMethods
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Solution::UrlSterilize

  spam_watcher_callbacks
  rate_limit :rules => lambda{ |obj| Account.current.account_additional_settings_from_cache.resource_rlimit_conf['solution_articles'] }, :if => lambda{|obj| obj.rl_enabled? }
  
  acts_as_voteable
  
  
  serialize :seo_data, Hash
  
  attr_accessor :highlight_title, :highlight_desc_un_html, :tags_changed

  attr_accessible :title, :description, :user_id, :folder_id, :status, :art_type, 
    :thumbs_up, :thumbs_down, :delta, :desc_un_html, :import_id, :seo_data, :position
  
  acts_as_list :scope => :folder
  

  after_save      :set_mobihelp_solution_updated_time, :if => :content_changed?
  before_destroy  :set_mobihelp_solution_updated_time

  validates_presence_of :title, :description, :user_id , :account_id
  validates_length_of :title, :in => 3..240
  validates_numericality_of :user_id
  validate :status_in_default_folder
  
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  scope :visible, :conditions => ['status = ?',STATUS_KEYS_BY_TOKEN[:published]] 
  scope :newest, lambda {|num| {:limit => num, :order => 'modified_at DESC'}}
 
  scope :by_user, lambda { |user|
      { :conditions => ["user_id = ?", user.id ] }
  }

  scope :articles_for_portal, lambda { |portal| articles_for_portal_conditions(portal) }

  VOTE_TYPES = [:thumbs_up, :thumbs_down]

  def self.articles_for_portal_conditions(portal)
    { :conditions => [' solution_folders.category_id in (?) AND solution_folders.visibility = ? ',
        portal.portal_solution_categories.map(&:solution_category_id), Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone] ],
      :joins => :folder
    }
  end

  def type_name
    TYPE_NAMES_BY_KEY[art_type]
  end
  
  def status_name
    STATUS_NAMES_BY_KEY[status]
  end

  def published?
    status == STATUS_KEYS_BY_TOKEN[:published]
  end
  
  def to_param
    title_param = sterilize(title[0..100])
    id ? "#{id}-#{title_param.downcase.gsub(/[<>#%{}|()*+_\\^~\[\]`\s,=&:?;'@$"!.\/(\-\-)]+/, '-')}" : nil
  end

  def nickname
    title
  end
  
  def to_s
    nickname
  end

  def user_visibility
    vis_arr = [Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]]
    if User.current
      vis_arr << Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users]
      vis_arr << Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:agents] if User.current.agent?
      vis_arr << Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users] if User.current.has_company?
    end
    vis_arr
  end
  
  def to_xml(options = {})
     options[:root] = 'solution_article'# TODO-RAILS3:: In Rails3 Model.model_name.element returns only 'article' not 'solution_article'
     options[:indent] ||= 2
     options.merge!(Solution::Constants::API_OPTIONS.merge(:include => {}))
      xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => options[:except], :root => options[:root]) 
  end

  def meta_attributes
    { 
      :folder_id => solution_folder_meta.id,
      :folder => { 
        "category_id" => solution_folder_meta.solution_category_meta_id,
        "visibility" => solution_folder_meta.visibility,
        :customer_folders => solution_folder_meta.customer_folders.map {|cf| {"customer_id" => cf.customer_id} }
      }
    }
  end

  def as_json(options={})
    return super(options) if (options[:tailored_json].present? || 
        Account.current.launched?(:solutions_meta_read))
    options.merge!(Solution::Constants::API_OPTIONS)
    super options
  end

  # Added for portal customisation drop
  def self.filter(_per_page = self.per_page, _page = 1)
    paginate :per_page => _per_page, :page => _page
  end
  
  def to_liquid
    @solution_article_drop ||= Solution::ArticleDrop.new self
  end
  
  def article_title
    (seo_data[:meta_title].blank?) ? title : seo_data[:meta_title]
  end

  def article_description
    seo_data[:meta_description]
  end

  def article_keywords
    (seo_data[:meta_keywords].blank?) ? tags.join(", ") : seo_data[:meta_keywords]
  end

  def article_changes
    @article_changes ||= self.changes.clone
  end

  VOTE_TYPES.each do |method|
    define_method "toggle_#{method}!" do
      self.class.update_counters(self.id, method => 1, (VOTE_TYPES - [method]).first => -1 )
      meta_class.update_counters(self.parent_id, method => 1, (VOTE_TYPES - [method]).first => -1 )
      queue_quest_job if self.published?
      return true
    end

    define_method "#{method}!" do
      self.class.increment_counter(method, self.id)
      meta_class.increment_counter(method, self.parent_id)
      queue_quest_job if (method == :thumbs_up && self.published?)
      return true
    end
  end

  def reset_ratings
    self.class.update_all({:thumbs_up => 0, :thumbs_down => 0} ,{ :id => self.id})
    meta_class.update_counters(self.parent_id, :thumbs_up => -self.thumbs_up, :thumbs_down => -self.thumbs_down)
    self.votes.destroy_all
  end

  def self.article_type_option
    TYPES.map { |i| [I18n.t(i[1]), i[2]] }
  end

  def self.article_status_option
    STATUSES.map { |i| [I18n.t(i[1]), i[2]] }
  end
  
  # Instance level spam watcher condition
  def rl_enabled?
    self.account.features?(:resource_rate_limit)
  end

  def create_draft_from_article(opts = {})
    draft = build_draft_from_article(opts)
    draft.save
    draft
  end

  def build_draft_from_article(opts = {})
    draft = self.account.solution_drafts.build(draft_attributes(opts))
    draft
  end

  def draft_attributes(opts = {})
    draft_attrs = opts.merge(:article => self, :category_meta => folder.solution_category_meta)
    Solution::Draft::COMMON_ATTRIBUTES.each do |attribute|
      draft_attrs[attribute] = self.send(attribute)
    end
    draft_attrs
  end

  def set_status(publish)
    self.status = publish ? STATUS_KEYS_BY_TOKEN[:published] : STATUS_KEYS_BY_TOKEN[:draft]
  end

  def publish!
    set_status(true)
    save
  end
  
  def visible_in? portal
    folder.visible_in?(portal)
  end

  private

    def queue_quest_job
      Resque.enqueue(Gamification::Quests::ProcessSolutionQuests, { :id => self.id, 
        :account_id => self.account_id })
    end

    def set_mobihelp_solution_updated_time
      self.reload
      folder.category.update_mh_solutions_category_time
    end

    def content_changed?
      all_fields = [:modified_at, :status, :position]
      changed_fields = self.changes.symbolize_keys.keys
      (changed_fields & all_fields).any? or tags_changed
    end

    def status_in_default_folder
      if status == STATUS_KEYS_BY_TOKEN[:published] and self.folder.is_default
        errors.add(:status, I18n.t('solution.articles.cant_publish'))
      end
    end
    
    def hit_key
      SOLUTION_HIT_TRACKER % {:account_id => account_id, :article_id => id }
    end

    def rl_exceeded_operation
      key = "RL_%{table_name}:%{account_id}:%{user_id}" % {:table_name => self.class.table_name, :account_id => self.account_id,
            :user_id => self.user_id }
      $spam_watcher.rpush(ResourceRateLimit::NOTIFY_KEYS, key)
    end
    
end
