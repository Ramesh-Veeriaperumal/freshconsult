class Bot < ActiveRecord::Base
  include Redis::OthersRedis
  include Redis::RedisKeys

  self.primary_key = :id

  attr_accessible :name, :portal_id, :template_data, :enable_in_portal
  attr_protected :account_id

  attr_accessor :training_completed

  concerned_with :presenter

  validates :enable_in_portal, inclusion: { in: [true, false] }
  validates :external_id, uniqueness: true
  validates :portal_id, uniqueness: true

  before_create :set_external_id
  after_create :training_not_started!
  before_update :check_constant_fields
  before_destroy :cleanup # Destroy bot ticket mappings, feedbacks and feedback mappings.

  has_one :logo,
          as: :attachable,
          class_name: 'Helpdesk::Attachment',
          dependent: :destroy

  belongs_to :product
  belongs_to :portal
  belongs_to_account

  has_many :bot_feedbacks, class_name: '::Bot::Feedback'
  has_many :bot_tickets, class_name: 'Bot::Ticket'
  has_many :tickets,
           class_name: 'Helpdesk::Ticket',
           through: :bot_tickets

  has_many :portal_solution_categories,
           class_name: 'PortalSolutionCategory'

  has_many :solution_category_meta,
           class_name: 'Solution::CategoryMeta',
           through: :portal_solution_categories

  serialize :template_data, Hash
  serialize :additional_settings, Hash

  UPDATE_DISALLOWED_FIELDS = %w[external_id portal_id product_id account_id].freeze

  def check_constant_fields
    (changes.keys & UPDATE_DISALLOWED_FIELDS).empty?
  end

  def training_not_started!
    set_others_redis_key(status_redis_key, BotConstants::BOT_STATUS[:training_not_started])
  end

  def training_inprogress!
    set_others_redis_key(status_redis_key, BotConstants::BOT_STATUS[:training_inprogress])
  end

  def training_completed!
    set_others_redis_key(status_redis_key, BotConstants::BOT_STATUS[:training_completed])
  end

  def clear_status
    remove_others_redis_key(status_redis_key)
  end

  def status_redis_key
    BOT_STATUS % { account_id: Account.current.id, bot_id: id }
  end

  def render_widget_code?
    enable_in_portal && training_completed?
  end

  def training_status
    get_others_redis_key(status_redis_key)
  end

  def self.default_profile
    profile_json = {
      theme_colour: BotConstants::DEFAULT_BOT_THEME_COLOUR,
      widget_size: BotConstants::DEFAULT_WIDGET_SIZE
    }
    profile_json
  end

  def profile
    default = default_avatar?
    avatar_id = additional_settings[:avatar_id] if default
    avatar_hash = {
      url: cdn_url,
      avatar_id: avatar_id,
      is_default: default
    }
    profile_hash = {
      name: name,
      avatar: avatar_hash,
      header: template_data[:header],
      theme_colour: template_data[:theme_colour],
      widget_size: template_data[:widget_size]
    }
    profile_hash
  end

  def cdn_url
    return if default_avatar?
    cdn_url = logo.content.url.gsub(BOT_CONFIG[:avatar_bucket_url], BOT_CONFIG[:avatar_cdn_url]) if logo && logo.content
    cdn_url
  end

  def category_ids=(category_ids = [])
    self.portal_solution_category_ids = self.portal.portal_solution_categories.where(solution_category_meta_id: category_ids).pluck(:id)
  end

  private

    def default_avatar?
      additional_settings.present? && additional_settings[:is_default]
    end

    def set_external_id
      self.external_id = UUIDTools::UUID.timestamp_create.hexdigest
    end

    def cleanup
      ::Bot::Cleanup.perform_async(bot_id: self.id)
    end

    def training_completed?
      get_others_redis_key(status_redis_key).to_i == BotConstants::BOT_STATUS[:training_completed] || !redis_key_exists?(status_redis_key)
    end
end
