class ScheduledTicketExport < ScheduledExport

  include Cache::Memcache::ScheduledExport::ScheduledTicketExport

  MAX_NO_OF_SCHEDULED_EXPORTS_PER_ACCOUNT = 5
  MAX_NO_OF_EMAIL_RECIPIENTS_PER_SCHEDULED_EXPORT = 10
  MAX_FIELDS = 150
  S3_TICKETS_PATH = "data/helpdesk/scheduled_exports/tickets/%{schedule_id}/%{filename}"
  NAME = "name"

  has_one :scheduled_task,
          :class_name => "::Helpdesk::ScheduledTask",
          :as => :schedulable,
          :dependent => :destroy

  default_scope -> { where(schedule_type: SCHEDULE_TYPE[:SCHEDULED_TICKET_EXPORT]) }

  attr_accessible :filter_data, :fields_data, :schedule_details

  SCHEDULE_DETAILS_KEYS = [:delivery_type, :email_recipients, :frequency, 
                           :day_of_export, :minute_of_day, :initial_export]

  serialize :filter_data, Array
  serialize :fields_data, Hash
  serialize :schedule_details, Hash

  concerned_with :validations

  before_create :set_user_id

  after_commit :clear_scheduled_exports_account_cache
  after_commit :sync_to_service
  after_commit :schedule_first_export, on: :create
  after_commit :clear_export_payload_enricher_config

  SCHEDULE_DETAILS_KEYS.each do |key|
    define_method(key) { schedule_details[key] }
  end

  DELIVERY_FREQUENZY_BY_KEYS.each do |type, val|
    define_method("#{type}?") do
      frequency.to_i == val
    end
  end

  def params_for_service
    {
      :user_id         => user_id,
      :time_zone       => user.time_zone,
      :fields_data     => fields_data,
      :filter_data     => not_deleted_or_spam | agent_tkt_permission | filter_data,
      :frequency        => frequency,
      :minute_of_day    => minute_of_day,
      :day_of_frequency => day_of_export,
      :class_name       => 'Ticket' #To Do
    }
  end

  def frequency_name
    DELIVERY_FREQUENZY_BY_VALUE[frequency.to_i]
  end

  def download_url created_at = nil
    Rails.application.routes.url_helpers.
      download_file_reports_scheduled_export_url(self, :host => account.host,
                                               :protocol => account.url_protocol,
                                               :created_at => created_at)
  end

  def api_url
    "#{download_url}.json"
  end

  def send_email?
    DELIVERY_TYPES[self.schedule_details[:delivery_type]] == :email
  end

  def api?
    DELIVERY_TYPES[self.schedule_details[:delivery_type]] == :api
  end

  def email_subject
    I18n.t('export_data.scheduled_ticket_export.subject',
            :title => name,
            :date => latest_schedule_time)
  end

  def email_description
    I18n.t('export_data.scheduled_ticket_export.body',
            :url => download_url(created_at_label),
            :user_name => user.name,
            :helpdesk_name => account.name,
            :latest_schedule_range => latest_schedule_range)
  end

  def email_no_data_subject
    I18n.t('export_data.scheduled_ticket_export_no_data.subject',
            :title => name)
  end

  def email_no_data_description
    I18n.t('export_data.scheduled_ticket_export_no_data.body',
            :user_name => user.name,
            :helpdesk_name => account.name,
            :latest_schedule_range => latest_schedule_range)
  end

  def latest_schedule_time
    case frequency_name
      when :hourly
        "#{Time.zone.now.day.ordinalize}
        #{Time.zone.now.beginning_of_hour.advance(hours: -1).strftime("%b %Y, %H:%M")} -
        #{Time.zone.now.beginning_of_hour.strftime("%H:%M")}".squish
      when :daily
        "#{Time.zone.now.day.ordinalize} #{Time.zone.now.strftime("%b %Y")}"
      when :weekly
        last_week_time = Time.zone.now.advance(days: -7)
        "#{last_week_time.day.ordinalize} #{last_week_time.strftime("%b %Y")} -
        #{Time.zone.now.day.ordinalize} #{Time.zone.now.strftime("%b %Y")}".squish
    end
  end

  def latest_schedule_range
    case frequency_name
      when :hourly
        time = Time.zone.now
        "#{Time.zone.now.beginning_of_hour.advance(hours: -1).strftime("%H:%M")} to 
        #{Time.zone.now.beginning_of_hour.strftime("%H:%M")} on 
        #{Time.zone.now.day.ordinalize} #{Time.zone.now.strftime("%b %Y")}".squish
      when :daily
        time = "#{sprintf('%02d', minute_of_day)}:00"
        "#{Time.zone.now.advance(days: -1).strftime("%B %d, %Y")} #{time} to
        #{Time.zone.now.strftime("%B %d, %Y")} #{time}".squish
      when :weekly
        time = "#{sprintf('%02d', minute_of_day)}:00"
        last_week_time = Time.zone.now.advance(days: -7)
        "#{last_week_time.strftime("%B %d, %Y")} #{time} to
        #{Time.zone.now.strftime("%B %d, %Y")} #{time}".squish
    end
  end

  def file_exists? filename=nil
    return false if latest_file.blank?
    path = S3_TICKETS_PATH % { :schedule_id => id,
                                :filename => filename || latest_file }
    AwsWrapper::S3.exists?(S3_CONFIG[:bucket], path)
  end

  def export_path filename=nil
    path = S3_TICKETS_PATH % { :schedule_id => id,
                                :filename => filename || latest_file }
    AwsWrapper::S3.presigned_url(S3_CONFIG[:bucket], path, secure: true)
  end

  def sync_to_service update=nil
    action = update || (transaction_include_action?(:create) ? :create : :destroy)
    args = { :action => action, :account_id => account_id, :filter_id => self.id }
    ScheduledExport::Ticket::Config.perform_async(args)
  end

  def ticket_fields
    self.fields_data["ticket"].present? ? self.fields_data["ticket"].keys : []
  end

  def user_fields
    self.fields_data["contact"].present? ? self.fields_data["contact"].keys : []
  end

  def company_fields
    self.fields_data["company"].present? ? self.fields_data["company"].keys : []
  end

  def filter_fields
    self.filter_data.present? ? 
        self.filter_data.collect {|data| [data["name"]] + nested_rules(data)}.flatten.compact : []
  end

  def agent_emails
    email_recipients.inject([]) do |emails, user_id|
      u = account.agents_details_from_cache.detect { |usr| usr.id == user_id }
      emails << u.email if u.present?
      emails
    end
  end

  def custom_filter_data
    ff_fields = Account.current.flexifields_with_ticket_fields_from_cache
    ret = []
    filter_data.clone.each do |f|
      field = ff_fields.detect{|field| field.flexifield_alias == f["name"]}
      ret << {
              "condition" => parse_condition(f, field),
              "value" => parse_value(f),
              "operator" => f["operator"]
            }
    end
    ret
  end

  def has_api_permission? current_user_id
    api? && user_id == current_user_id
  end

  def has_email_permission? current_user_id
    send_email? && (user_id == current_user_id || email_recipients.include?(current_user_id))
  end

  def created_at_label
    case frequency_name
      when :hourly
        Time.zone.now.beginning_of_hour.strftime("%Y-%m-%dT%H:00")
      when :daily, :weekly
        Time.zone.now.strftime("%Y-%m-%d")
    end
  end

  def file_timestamp(time = Time.zone.now)
    exp = hourly? ? "%B-%d-%Y-%H-00" : "%B-%d-%Y"
    "#{frequency_name}-#{time.strftime(exp)}"
  end

  def file_name(time = nil)
    return nil unless time
    time = Time.parse(time)
    "tickets-#{file_timestamp(time)}.csv"
  end

  private

    def set_user_id
      self.user_id ||= User.current.id if User.current
    end

    def agent_tkt_permission
      if user.all_tickets_permission?
          []
      elsif user.assigned_tickets_permission?
          [agent_condition]
      elsif user.group_tickets_permission?
          [group_condition]
      end
    end

    def not_deleted_or_spam
      [{"name"=>"deleted", "operator"=>"is", "value"=>"false"},
        {"name"=>"spam", "operator"=>"is", "value"=>"false"}]
    end

    def schedule_first_export
      emails = {}
      self.email_recipients.each do |e|
        ag = account.agents_details_from_cache.detect { |u| u.id == e }
        next unless ag.present?
        emails[ag.email] = e
      end

      task_params = {
        :frequency => self.frequency,
        :minute_of_day => self.minute_of_day.to_i * 60,
        :day_of_frequency => self.day_of_export,
        :start_date => Time.zone.now.utc,
        :status => ::Helpdesk::ScheduledTask::STATUS_NAME_TO_TOKEN[:available]
      }

      schedule_task = self.build_scheduled_task(task_params)

      schedule_config_params = {
        :emails => emails,
        :fields => self.fields_data
      }

      schedule_config = schedule_task.schedule_configurations.build(
        :notification_type =>
          Helpdesk::ScheduleConfiguration::NOTIFICATION_TYPE_TO_TOKEN[:email_notification],
        :description => self.email_description,
        :config_data => schedule_config_params
      )
      schedule_task.save
    end

    def clear_export_payload_enricher_config
      Export::EnricherHelper.clear_export_payload_enricher_config
    end

    def nested_rules data
      return [] if data["nested_rules"].blank?
      data["nested_rules"].map{|d| d[:name]}
    end

    def parse_condition f, field
      if field
        "flexifields.#{field.flexifield_name}"
      elsif f["name"].eql?('product_id')
        "helpdesk_schema_less_tickets.product_id"
      elsif f["name"].eql?('tag_names')
        "helpdesk_tags.name"
      else
        f["name"]
      end
    end

    def parse_value f
      if f["value"].is_a?(Array)
        f["value"].map! {|v| v.blank? ? NONE_VALUE : v }
        f["value"].join(',')
      else
        f["value"].blank? ? NONE_VALUE : f["value"]
      end
    end

    def agent_condition
      if Account.current.shared_ownership_enabled?
        {"type"=>"or", "operator"=>"is", 
          "rules" => [
            {"name"=>"responder_id", "value"=> user_id}, 
            {"name"=>"internal_agent_id", "value"=> user_id}
          ]
        }
      else
        {"name"=>"responder_id", "operator"=>"is", "value"=>user_id}
      end
    end

    def group_condition
      group_ids = user.agent_groups.pluck(:group_id)
      group_ids << '' if group_ids.blank?
      if Account.current.shared_ownership_enabled?
        {"type"=>"or", "operator"=>"is", 
          "rules" => [
            {"name"=>"responder_id", "value"=> user_id}, 
            {"name"=>"group_id", "value" => group_ids},
            {"name"=>"internal_agent_id", "value"=> user_id},
            {"name"=>"internal_group_id", "value"=> group_ids}
          ]
        }
      else
        {"type"=>"or", "operator"=>"is", 
          "rules" => [
            {"name"=>"responder_id", "value"=> user_id}, 
            {"name"=>"group_id", "value"=> group_ids}
          ]
        }
      end
    end
end
