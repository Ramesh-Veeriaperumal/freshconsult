# encoding: utf-8
class Solution::Article < ActiveRecord::Base
  self.primary_key= :id
  self.table_name =  "solution_articles"
  belongs_to_account
  concerned_with :associations, :body_methods, :esv2_methods, :presenter

  publishable

  before_destroy :save_deleted_article_info
  before_save :encode_emoji_in_articles

  include Juixe::Acts::Voteable
  include Search::ElasticSearchIndex
  include Email::Antivirus::EHawk

  belongs_to :recent_author, :class_name => 'User', :foreign_key => "modified_by"
  has_one :draft, inverse_of: :article, :dependent => :destroy

  include Solution::LanguageMethods

  include Mobile::Actions::Article
  include Solution::Constants

  include Community::HitMethods
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Solution::UrlSterilize
  include Solution::Activities
  include Solution::ArticleFilterScoper
  include Solution::SolutionMethods

  spam_watcher_callbacks

  acts_as_voteable

  serialize :seo_data, Hash

  attr_accessor :highlight_title, :highlight_desc_un_html, :tags_changed, :prev_tags, :latest_tags, :session,
                :unpublishing, :false_delete_attachment_trigger, :attachment_added, :version_through,
                :model_changes, :interaction_source_id, :interaction_source_type, :interaction_platform, :tag_changes, :templates_used

  alias_attribute :body, :article_body
  alias_attribute :suggested, :int_01
  alias_attribute :name, :title
  attr_accessible :title, :description, :user_id, :status, :import_id, :seo_data, :outdated

  validates_presence_of :title, :description, :user_id , :account_id
  validates_length_of :title, :in => 3..240
  validates_numericality_of :user_id
  validates_uniqueness_of :language_id, :scope => [:account_id , :parent_id], :if => "!solution_article_meta.new_record?"
  validates_inclusion_of :status, :in => [STATUS_KEYS_BY_TOKEN[:draft], STATUS_KEYS_BY_TOKEN[:published]]
  validate :status_in_default_folder
  validate :check_for_spam_content

  after_commit :tag_update_central_publish, on: :update, :if => :tags_updated?

  # Callbacks will be executed in the order in which they have been included.
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  alias_method :parent, :solution_article_meta

  scope :visible, -> { where(status: STATUS_KEYS_BY_TOKEN[:published]) }
  scope :newest, -> (num) { order('modified_at DESC').limit(num) }

  scope :by_user, -> (user) { where(user_id: user.id) }

  scope :articles_for_portal, -> (portal) { articles_for_portal_conditions(portal) }

  scope :most_viewed, -> (count) {
    where(
      status:STATUS_KEYS_BY_TOKEN[:published],
      language_id: (Language.current? ? Language.current.id : Language.for_current_account.id)
    ).
    order('hits DESC').
    limit(count)
  }

  delegate :visible_in?, :to => :solution_folder_meta
  delegate :visible?, :to => :solution_folder_meta

  xss_sanitize only: [:title], plain_sanitizer: [:title]

  VOTE_TYPES = [:thumbs_up, :thumbs_down]
  VOTE_COUNTERS = [:reset, :toggle].freeze


  VOTES = {
    thumbs_up: 1,
    thumbs_down: 0
  }.freeze

  PUBLISH_DETAILS_RENAMED_KEYS = {
    modified_at: :published_at,
    modified_by: :published_by
  }.freeze

  SELECT_ATTRIBUTES = ["id", "thumbs_up", "thumbs_down"]


  def model_changes
    @model_changes ||= {}
  end

  def publish_draft_changes_to_central(draft_changes)
    model_changes[:draft_modified_at] = draft_changes[:modified_at] if draft_changes.key?(:modified_at)
    model_changes[:draft_modified_by] = draft_changes[:user_id] if draft_changes.key?(:user_id)
    model_changes[:draft_exists] = draft_changes[:draft_exists] if draft_changes.key?(:draft_exists)
    manual_publish_to_central(nil, :update, {}, false) unless model_changes.empty?
  end

  def publish_approver_changes_to_central(approver_changes)
    return unless Account.current.article_approval_workflow_enabled?

    model_changes[:approved_at] = approver_changes[:approved_at] if approver_changes.key?(:approved_at)
    model_changes[:approved_by] = approver_changes[:approved_by] if approver_changes.key?(:approved_by)
    model_changes[:approval_status] = approver_changes[:approval_status] if approver_changes.key?(:approval_status)
    manual_publish_to_central(nil, :update, {}, false) unless model_changes.empty?
  end

  def tag_update_central_publish
    @latest_tags = self.tags.map(&:name)
    tag_args = {}
    tag_args[:added_tags] = @latest_tags - @prev_tags
    tag_args[:removed_tags] = @prev_tags - @latest_tags
    CentralPublish::UpdateTag.perform_async(tag_args)
  end

  def merge_bulk_publish_payload(status = STATUS_KEYS_BY_TOKEN[:draft])
    model_changes.merge!(status: [status, STATUS_KEYS_BY_TOKEN[:published]])
    update_publish_details
  end

  def add_tag_activity(tag)
    if tag_changes.present?
      tag_changes[:added_tags].present? ? tag_changes[:added_tags] << tag.name : tag_changes[:added_tags] = [tag.name]
    else
      self.tag_changes = { added_tags: [tag.name] }
    end
  end

  def remove_tag_activity(tag)
    if tag_changes.present?
      tag_changes[:removed_tags].present? ? tag_changes[:removed_tags] << tag.name : tag_changes[:removed_tags] = [tag.name]
    else
      self.tag_changes = { removed_tags: [tag.name] }
    end
  end

  def save_tags
    @prev_tags = self.tags.map(&:name)
  end

  def tags_updated?
    self.tags_changed
  end

  def self.articles_for_portal_conditions(portal)
    { :conditions => [' solution_folders.category_id in (?) AND solution_folders.visibility = ? ',
        portal.portal_solution_categories.map(&:solution_category_id), Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone] ],
      :joins => :folder
    }
  end

  def self.has_multi_language_article?
    select('distinct language_id').limit(2).length > 1
  end

  def self.portal_articles(portal_id, language_ids)
    joins({ solution_folder_meta: [solution_category_meta: :portal_solution_categories] }).where('portal_solution_categories.portal_id = ? AND solution_articles.language_id IN (?)', portal_id, language_ids)
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

  def draft_present?
    draft.present?
  end

  def available?
    present?
  end
  
  def to_param
    return parent_id if new_record?
    title_param = sterilize(title[0..100])
    parent_id ? "#{parent_id}-#{title_param.downcase.gsub(/[<>#%{}|()*+_\\^~\[\]`\s,=&:?;'@$"!.\/(\-\-)]+/, '-')}" : nil
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

  def author_update_details
    return {} unless previous_changes.key?(:agent_id)

    { agent_name: previous_changes[:agent_id].map { |id| Account.current.users.find(id).name } }
  end

  def folder_update_details
    return {} unless parent.previous_changes.key?(:solution_folder_meta_id)

    { solution_folder_name: parent.previous_changes[:solution_folder_meta_id].map { |id| fetch_folder_name(id) } }
  end

  def update_unpublish_details
    if published_to_draft?
      # modified by can be the same(same user who published, unpublishes) and so cannot rely on modified's model changes
      PUBLISH_DETAILS_RENAMED_KEYS.each do |old_key, new_key|
        model_changes[new_key] = previous_changes.key?(old_key) ? [previous_changes[old_key][0], nil] : [safe_send(old_key.to_s), nil]
      end
    end
  end

  def update_publish_details
    if published?
      # For bulk publish, status changes will not be present in previous_changes. Check update_status in solution_bulk_action_concern
      previous_changes[:status] = model_changes[:status] if !previous_changes.key?(:status) && model_changes[:status]
      if draft_to_published?
        # modified by can be the same(same user who created draft, published) and so cannot rely on modified's model changes
        PUBLISH_DETAILS_RENAMED_KEYS.each do |old_key, new_key|
          model_changes[new_key] = previous_changes.key?(old_key) ? [nil, previous_changes[old_key][1]] : [nil, safe_send(old_key.to_s)]
        end
      else
        PUBLISH_DETAILS_RENAMED_KEYS.each do |old_key, new_key|
          model_changes[new_key] = previous_changes[old_key] if previous_changes.key?(old_key)
        end
      end
      # For bulk publish we will have to remove status from model changes after construction published_at/by
      model_changes.delete(:status) if model_changes[:status] == [STATUS_KEYS_BY_TOKEN[:published], STATUS_KEYS_BY_TOKEN[:published]]
    end
  end

  def fetch_folder_name(id)
    Account.current.solution_folders.where(parent_id: id, language_id: language_id).first.name
  end

  def as_json(options={})
    return super(options) if (options[:tailored_json].present?)
    old_options = options.dup
    options.merge!(Solution::Constants::API_OPTIONS.deep_dup)
    options[:except] += (old_options[:except] || [])
    options[:except].each {|ex| options[:include].delete(ex)}
    super options
  end

  # Added for portal customisation drop
  def self.filter(_per_page = self.per_page, _page = 1)
    paginate :per_page => _per_page, :page => _page
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

  def outdated=(value)
    if is_primary?
      parent.children.each do |article|
        article.outdated = value unless article.is_primary? || article.outdated == value
      end
    else
      super(value) unless outdated == value
    end
  end

  def meta_class
    "Solution::ArticleMeta".constantize
  end

  def version_class
    "Solution::ArticleVersion".constantize
  end

  VOTE_TYPES.each do |method|
    define_method "toggle_#{method}!" do
      toggle_method = (VOTE_TYPES - [method]).first
      self.class.update_counters(self.id, method => 1, toggle_method => -1 )
      meta_class.update_counters(self.parent_id, method => 1, toggle_method => -1 )
      manual_publish_interaction(:toggle, method)
      version_class.update_counters(self.live_version.id, method => 1, toggle_method => -1 ) if Account.current.article_versioning_enabled? && self.live_version
      self.sqs_manual_publish #=> Publish to ES
      queue_quest_job if self.published?
      return true
    end

    define_method "#{method}!" do
      self.class.increment_counter(method, self.id)
      meta_class.increment_counter(method, self.parent_id)
      version_class.increment_counter(method, self.live_version.id) if Account.current.article_versioning_enabled? && self.live_version
      self.sqs_manual_publish #=> Publish to ES
      manual_publish_interaction(:incr, method)
      queue_quest_job if (method == :thumbs_up && self.published?)
      return true
    end
    
    define_method "#{method}=" do |value|
      logger.warn "WARNING!! Assigning #{method.to_s} in this manner is not advised. Please make use of object.#{method.to_s}!"
      return unless new_record?
      solution_article_meta.safe_send("#{method}=", (solution_article_meta.safe_send("#{method}") + value))
      super(value) 
    end
  end

  def suggested!
    self.class.increment_counter('int_01', self.id)
    set_portal_interaction_source
    manual_publish_interaction(:incr, :suggested)
  end

  def templates_used=(templates_used)
    return unless Account.current.solutions_templates_enabled?

    valid_template_ids = Account.current.solution_templates.where(id: templates_used).pluck(:id)
    unless valid_template_ids.empty?
      existing_template_ids = solution_template_mappings.where(template_id: valid_template_ids).pluck(:template_id)
      missing_template_ids = valid_template_ids - existing_template_ids
      missing_template_ids.each { |tid| solution_template_mappings.build(template_id: tid, used_cnt: 1) }
      existing_mapping_ids = solution_template_mappings.where(template_id: existing_template_ids).pluck(:id)
      # solution_template_mappings.where(template_id: existing_template_ids).update_all('used_cnt = used_cnt+1')
      Solution::TemplateMapping.update_counters(existing_mapping_ids, used_cnt: 1) unless existing_mapping_ids.empty? # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def reset_ratings
    set_portal_interaction_source
    manual_publish_interaction(:reset) # publish before updating counters
    self.class.where({ :id => self.id}).update_all_with_publish({:thumbs_up => 0, :thumbs_down => 0}, {})
    meta_class.update_counters(self.parent_id, :thumbs_up => -self.thumbs_up, :thumbs_down => -self.thumbs_down)
    if Account.current.article_versioning_enabled?
      version_class.where({ :id => self.live_version.id}).update_all({:thumbs_up => 0, :thumbs_down => 0}) if self.live_version
      job_id = Solution::ArticleVersionsResetRating.perform_async({ id: self.id })
      Rails.logger.info("AVRR:: Reset Rating [Account Id :: #{account_id} :: Article Id : #{id} :: Job Id : #{job_id}]")
    end
    self.votes.destroy_all
  end

  def manual_publish_interaction(counter, interaction = :thumbs_up)
    reload
    count = safe_send(interaction.to_s)
    if VOTE_COUNTERS.include? counter
      # :reset and :toggle
      vote_model_changes(counter, interaction, count)
    elsif counter == :incr
      # :thumbs_up, thumbs_down, :suggested, :hits
      self.model_changes["article_#{interaction}"] = prev_curr_count(counter, count)
      meta_model_changes(counter, interaction) if (VOTE_TYPES.include? interaction) || interaction == :hits
    end
    manual_publish_to_central(nil, :interactions, {}, false)
  end

  def set_portal_interaction_source
    current_portal = Portal.current || Account.current.main_portal
    set_interaction_source(:portal, current_portal.id)
  end

  def set_interaction_source(source_type, source_id, platform = nil)
    self.interaction_source_type = INTERACTION_SOURCE[source_type]
    self.interaction_source_id = source_id
    self.interaction_platform = platform
  end

  def self.article_type_option
    TYPES.map { |i| [I18n.t(i[1]), i[2]] }
  end

  def self.article_status_option
    STATUSES.map { |i| [I18n.t(i[1]), i[2]] }
  end

  def create_draft_from_article(opts = {})
    draft = build_draft_from_article(opts)
    draft.false_delete_attachment_trigger = false_delete_attachment_trigger
    draft.save
    draft
  end

  def build_draft_from_article(opts = {})
    draft = self.account.solution_drafts.build
    draft_attributes(opts).each do |k, v|
      draft.safe_send("#{k}=", v)
    end
    draft
  end

  def draft_attributes(opts = {})
    draft_attrs = opts.merge(:article_id => self.id, :category_meta_id => solution_folder_meta.solution_category_meta_id)
    Solution::Draft::COMMON_ATTRIBUTES.each do |attribute|
      draft_attrs[attribute] = self.safe_send(attribute)
    end
    draft_attrs
  end

  def set_status(publish)
    self.status = publish ? STATUS_KEYS_BY_TOKEN[:published] : STATUS_KEYS_BY_TOKEN[:draft]
  end

  def publish!
    set_status(true)
    published = save
    published
  end

  def to_liquid
    @solution_article_drop ||= Solution::ArticleVersionDrop.new self
  end
  
  def folder_id
    # To make Gamification work
    @folder_id ||= solution_article_meta.solution_folder_meta_id
  end

  def save_deleted_article_info
    @deleted_model_info = as_api_response(:central_publish_destroy) 
  end

  def clear_approvals
    helpdesk_approval.try(:destroy)
  end

  def agent_portal_url(relative_url = false)
    main_portal = Account.current.main_portal
    portal = Account.current.portal_solution_categories.find_by_solution_category_meta_id(solution_folder_meta.solution_category_meta_id).try(:portal) || main_portal
    relative_link = "/a/solutions/articles/#{parent_id}"

    query_params = {}
    query_params[:lang] = language_code if Account.current.multilingual?
    query_params[:portalId] = portal.id if Account.current.features?(:multi_product) && Account.current.portals.size > 1

    relative_link += "?#{Rack::Utils.build_query(query_params)}" unless query_params.empty?

    relative_url ? relative_link : "#{main_portal.url_protocol}://#{main_portal.host}#{relative_link}"
  end

  # ====Article approval callbacks ======
  def approval_callback(action, _record)
    # we are utilizing the update RabbitMq::Publisher line 25.
    self.publish_update_article_to_rabbitmq unless action === 'destroy'
  end

  private

    def draft_to_published?
      previous_changes.key?(:status) && previous_changes[:status] == [STATUS_KEYS_BY_TOKEN[:draft], STATUS_KEYS_BY_TOKEN[:published]]
    end

    def published_to_draft?
      previous_changes.key?(:status) && previous_changes[:status] == [STATUS_KEYS_BY_TOKEN[:published], STATUS_KEYS_BY_TOKEN[:draft]]
    end

    def vote_model_changes(counter, interaction, count)
      # This method is only for :reset and :toggle as both thumbs_up, thumbs_down of both article and article_meta changes
      counter = :incr if counter == :toggle
      toggle_counter = counter == :reset ? :reset : :decr
      toggle_interaction = (VOTE_TYPES - [interaction]).first
      toggle_interaction_count = safe_send(toggle_interaction.to_s)
      count_by = counter == :reset ? count : 1
      toggle_count_by = counter == :reset ? toggle_interaction_count : 1
      self.model_changes["article_#{interaction}"] = prev_curr_count(counter, count, count_by)
      self.model_changes["article_#{toggle_interaction}"] = prev_curr_count(toggle_counter, toggle_interaction_count, toggle_count_by)
      meta_model_changes(counter, interaction, count_by)
      meta_model_changes(toggle_counter, toggle_interaction, toggle_count_by)
    end

    def meta_model_changes(counter, interaction, count_by = 1)
      meta_count = parent.safe_send(interaction.to_s)
      self.model_changes.merge!(interaction => prev_curr_count(counter, meta_count, count_by))
    end

    def prev_curr_count(counter, count, count_by = 1)
      case counter
      when :reset
        [count, count - count_by]
      when :incr
        [count - count_by, count]
      when :decr
        [count + count_by, count]
      else
        [count, count]
      end
    end

    def queue_quest_job
      args = { :id => self.id, :account_id => self.account_id }
      Gamification::ProcessSolutionQuests.perform_async(args)
    end

    def status_in_default_folder
      parent = self.solution_folder_meta
      if status == STATUS_KEYS_BY_TOKEN[:published] && (parent.present? && parent.is_default?)
        errors.add(:status, I18n.t('solution.articles.cant_publish'))
      end
    end
    
    def hit_key
      SOLUTION_HIT_TRACKER % {:account_id => account_id, :article_id => id }
    end

    def to_rmq_json(keys,action)
      article_identifiers
      #destroy_action?(action) ? article_identifiers : return_specific_keys(article_identifiers, keys)
    end

    def article_identifiers
      @rmq_article_identifiers ||= {
        "id"            =>  id,
        "user_id"       =>  user_id,
        "folder_id"     =>  folder_id,
        "status"        =>  status,
        "art_type"      =>  art_type,
        "thumbs_down"   =>  thumbs_down,
        "thumbs_up"     =>  thumbs_up,
        "parent_id"     =>  parent_id,
        "modified_by"   =>  modified_by,
        "modified_at"   =>  modified_at,
        "language"      =>  language,
        "hits"          =>  hits
      }
    end
    
    def check_for_spam_content
      if !self.account.kbase_spam_whitelist_enabled? && self.account.subscription.trial? && self.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
        article_spam_regex = Regexp.new($redis_others.perform_redis_op("get", ARTICLE_SPAM_REGEX), "i")

        article_phone_number_spam_regex = Regexp.new($redis_others.perform_redis_op("get", PHONE_NUMBER_SPAM_REGEX), "i")
        article_content_spam_char_regex = Regexp.new($redis_others.perform_redis_op("get", CONTENT_SPAM_CHAR_REGEX))
        stripped_title = self.title.gsub(Regexp.new(Solution::Constants::CONTENT_ALPHA_NUMERIC_REGEX), "")

        if (self.title =~ article_spam_regex).present? || check_seo_data_for_spam(article_spam_regex) || (stripped_title =~ article_phone_number_spam_regex).present? || (self.title =~ article_content_spam_char_regex).present? || !self.account.active?
          errors.add(:title, "Possible spam content")
          subject = "Detected suspicious solution spam account :#{self.account_id} "
          additional_info = "Suspicious article title in Account ##{self.account_id} with ehawk_reputation_score: #{self.account.ehawk_reputation_score} : #{self.title}"
          increase_ehawk_spam_score_for_account(4, self.account, subject, additional_info)
          Rails.logger.info ":::::: Kbase spam content encountered - increased spam reputation for article ##{self.id} in account ##{self.account.id}  :::::::"
        end
      end
    end

    def check_seo_data_for_spam(article_spam_regex)
      self.seo_data.each do |seo_key, value|
        return true if (value =~ article_spam_regex).present?
      end
      return false
    end
end
