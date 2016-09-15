class ExportAgents < BaseWorker

  include ExportCsvUtil
  include Rails.application.routes.url_helpers
  include Export::Util

  sidekiq_options :queue => :export_agents, :retry => 0, :backtrace => true, :failures => :exhausted

  AGENT_TICKET_SCOPE = { 1 => 'agent.global', 2 => 'agent.group', 3 => 'agent.individual' }

  def perform args
    begin
      @agents = Account.current.agents.includes({:user => :roles},:agent_groups)
      @csv_hash = args["csv_hash"]
      @portal_url = args["portal_url"]
      User.current = Account.current.users.find_by_id(args["user"])
      TimeZone.set_time_zone
      I18n.locale = (User.current and User.current.language) ? User.current.language : Account.current.language
      export_data
    ensure
      User.reset_current_user
      I18n.locale = I18n.default_locale
    end
  end

  private

    def export_data
      @headers = @csv_hash.keys
      unless @csv_hash.blank?
        csv_string = CSVBridge.generate do |csv|
          csv << @headers
          map_csv csv
        end
      end

      check_and_create_export('agent')
      build_file(csv_string, 'agent')
      mail_to_user
    end

    def map_csv csv
      @agents.each do |agent|
        csv_data = []
        @headers.each do |val|
          csv_data << strip_equal(send(@csv_hash[val], agent))
        end
        csv << csv_data if csv_data.any?
      end
    end

    ["name", "phone", "mobile", "language", "time_zone", "email"].each do |identifier|
      define_method("agent_#{identifier}") do |agent|
        if identifier == "language"
          agent.user.language_name
        else
          agent.user.send(identifier)
        end
      end
    end

    def agent_type agent
      agent.occasional ? I18n.t("agent.occasional_agent") : I18n.t("agent.full_time_agent")
    end
  
    def ticket_scope agent
      I18n.t(AGENT_TICKET_SCOPE[agent.ticket_permission])
    end

    def agent_roles agent
      agent.user.roles.map(&:name).to_sentence
    end

    def groups agent
      group_ids = agent.agent_groups.map(&:group_id)
      agent_groups = Account.current.groups_from_cache.select { |group| group_ids.include? group.id } 
      agent_groups.map(&:name).to_sentence
    end

    def last_active_at agent
        formated_date(agent.last_active_at) if agent.last_active_at
    end

    def formated_date(date_time)
      time_format = Account.current.date_type :short_day_with_week
      I18n.l date_time, :format => time_format
    end

    def mail_to_user
      DataExportMailer.send_later(:deliver_agent_export, {
        :user   => User.current, 
        :domain => @portal_url,
        :url    => hash_url(@portal_url)
      })
    end
end