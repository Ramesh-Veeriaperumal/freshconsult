class Helpdesk::ScheduleConfiguration < ActiveRecord::Base
  self.primary_key = :id
  self.table_name =  "schedule_configurations"

  belongs_to_account
  belongs_to :scheduled_task
  
  MAX_TO_EMAILS = 10
  
  NOTIFICATION_TYPE_TO_TOKEN = { :email_notification => 1 }
  NOTIFICATION_TOKEN_TO_TYPE = NOTIFICATION_TYPE_TO_TOKEN.invert

  JSON_OPTIONS = { :except  => [:account_id, :config_data, :description, :notification_type],
                   :methods => [:config, :notification]
                 }

  NOTIFICATION_TYPE_TO_TOKEN.each_pair do |k, v|
    define_method("#{k}?") do
      notification_type == v
    end
  end

  validates_length_of :description, :maximum => 1_000_003, :allow_blank => true
  validates_inclusion_of :notification_type, :in => NOTIFICATION_TOKEN_TO_TYPE.keys
  validate :validate_email_notification, :if => :email_notification?
  
  
  serialize :config_data, Hash
  
  scope :with_notification_type, ->(notification_type) {
    where(notification_type: NOTIFICATION_TYPE_TO_TOKEN[notification_type.to_sym]).limit(1)
  }

  def notification
    NOTIFICATION_TOKEN_TO_TYPE[notification_type]
  end

  def as_json options = {}
    super(options.merge! JSON_OPTIONS)
  end

  def config
    custom_config_method = "#{notification}_config"
    if defined? custom_config_method
      send custom_config_method
    else
      config_data
    end
  end

private

  def email_notification_config
    {
      :subject       => self.config_data[:subject],
      :emails        => self.config_data[:emails],
      :email_source  => emails_with_text,
      :description   => self.description
    }
  end

  def validate_email_notification
    emails = self.config_data[:emails].keys
    
    errors.add(:config_data, I18n.t('helpdesk_reports.scheduled_reports.errors.emails_limit', num: MAX_TO_EMAILS)) if emails.size > MAX_TO_EMAILS
    errors.add(:config_data, I18n.t('helpdesk_reports.scheduled_reports.errors.invalid_email')) unless valid_email?(emails)
  end
  
  def valid_email? email
    if email.is_a? Array
      !email.any? { |e| !e.match(AccountConstants::EMAIL_VALIDATOR) }
    else
      email.match(AccountConstants::EMAIL_VALIDATOR)
    end
  end

  def emails_with_text
    ids =  self.config_data[:emails].values.collect{|id| id.to_i}
    select_col = "id, name, blocked, deleted, helpdesk_agent"

    users = ids.present? ? Account.current.all_users.find_all_by_id(ids, select: select_col).collect{|u| [u.id, u]}.to_h : {}
    self.config_data[:emails].inject([]) do |result, (email, user_id)|
      user = users[user_id.to_i]
      res = { email: email }

      res.merge!({
        id: user_id,
        status: user_status(user),
        text: "#{user.name} <#{email}>"
        }) if user

      result << res
    end
  end

  # @Arun: revisit below method
  def user_status user
    if user.blocked || user.deleted
      return 2
    elsif self.config_data[:agents_status].include?(user.id) && !user.helpdesk_agent?
      return 3 
    else
      return 1
    end
  end
  
end