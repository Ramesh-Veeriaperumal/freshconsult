class Bot < ActiveRecord::Base

  self.primary_key = :id

  attr_accessible :name, :avatar, :portal_id, :template_data, :enable_in_portal

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

  serialize :template_data, Hash
  serialize :avatar, Hash
  serialize :additional_settings, Hash



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
end
