class Bot < ActiveRecord::Base

  include Redis::OthersRedis
  include Redis::RedisKeys

  self.primary_key = :id

  attr_accessible :name, :avatar, :portal_id, :template_data, :enable_in_portal

  attr_accessor :training_completed

  concerned_with :presenter

  validates :enable_in_portal, inclusion: {in: [true, false]}
  validates :external_id, uniqueness: true
  validates :portal_id, uniqueness: true

  has_one :logo,
          as: :attachable,
          class_name: 'Helpdesk::Attachment',
          dependent: :destroy

  belongs_to :product
  belongs_to :portal
  belongs_to_account

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
  serialize :avatar, Hash
  serialize :additional_settings, Hash


  def render_widget_code?
    enable_in_portal && (get_others_redis_key(status_redis_key).to_i == BotConstants::BOT_STATUS_HASH[:training_completed] || !redis_key_exists?(status_redis_key))
  end

  def status_redis_key
    BOT_STATUS % { account_id: Account.current.id, portal_id: portal_id }
  end


  def logo_url
    template_data[:logo_url]
  end

  def profile
    avatar_cdn = get_avatar_with_cdn 
    profile_hash = {
      name: name,
      avatar: avatar_cdn,
      header: template_data[:header],
      theme_colour: template_data[:theme_colour],
      widget_size: template_data[:size],
      #widget_position: template_data[:position],
      enable_in_portal: enable_in_portal
    }
    profile_hash
  end

  def get_avatar_with_cdn 
    avatar[:url] = avatar[:url].gsub(BOT_CONFIG[:avatar_bucket_url], BOT_CONFIG[:avatar_cdn_url]) unless avatar[:is_default] 
    avatar         
  end

  def category_ids=(category_ids = [])
    self.portal_solution_category_ids = self.portal.portal_solution_categories.where(solution_category_meta_id: category_ids).pluck(:id)
  end
end
