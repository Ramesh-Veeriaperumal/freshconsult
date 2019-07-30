class Freddy::Bot < ActiveRecord::Base

  include Redis::OthersRedis
  include Redis::RedisKeys

  self.primary_key = :id
  self.table_name = 'freddy_bots'

  attr_accessible :name, :portal_id, :widget_config, :status
  attr_protected :account_id
  before_update :check_constant_fields
  validates :status, inclusion: { in: [true, false] }
  validates :portal_id, uniqueness: true
  before_save :sanitize_widget_config
  xss_sanitize only: [:name], plain_sanitizer: [:name]
  belongs_to :portal
  belongs_to_account
  serialize :widget_config, Hash

  UPDATE_DISALLOWED_FIELDS = %w[portal_id account_id].freeze

  def check_constant_fields
    (changes.keys & UPDATE_DISALLOWED_FIELDS).empty?
  end

  def profile
    profile_hash = {
      name: name,
      welcome_message: widget_config[:header],
      background: widget_config[:theme_colour],
      color_scheme: widget_config[:widget_size]
    }
    profile_hash
  end

  def sanitize_widget_config
    widget_config.each do |key, value|
      widget_config[key].each do |key1, value1|
        widget_config[key][key1] = RailsFullSanitizer.sanitize(value1)
      end
    end
  end
end
