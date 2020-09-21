module Helpdesk::Activities
  module ActivityMethods
    include HelpdeskActivities::TicketActivities
    include Helpdesk::NotePropertiesMethods
    include Helpdesk::Email::Constants
    include EmailParser

    DEFAULT_STATUS_KEYS = Helpdesk::Ticketfields::TicketStatus::DEFAULT_STATUSES.keys

    DEFAULT_RET_HASH    = {
      :error      => "Internal server error",
      :error_code => "400"
    }

    def fetch_errored_email_details
      res_hash = DEFAULT_RET_HASH.clone
      params.symbolize_keys
      @ticket = @item
      object = params[:note_id].present? ? current_account.notes.where(id:params[:note_id]).first : @ticket
      response = get_object_activities object
      if response.error_message.present?
        private_email_failure? ? render_errors(res_hash) : (return res_hash)
      end
      email_failures = if response.ticket_data[0].present?
        JSON.parse(response.ticket_data[0].email_failures)
      else
        []
      end
      email_failures = email_failures.reduce Hash.new, :merge
      to_emails,cc_emails = object.to_cc_emails
      to_emails = to_emails.to_a if to_emails.is_a?(String)
      @to_list        = []
      @cc_list        = []
      regret_failure_count = 0
      email_failures.each do |email,error|
        user_email = current_account.users.where(email:email).first
        item_obj = {
          "email" => email,
          "type"  => FAILURE_CATEGORY[error.to_i]
        }
        item_obj.merge!("user"  => user_email.nil? ? "" : user_email) unless private_email_failure?
        @to_list.push(item_obj) if to_emails.include?(email)
        @cc_list.push(item_obj) if cc_emails.include?(email)
        regret_failure_count+=1 if !to_emails.include?(email) && !cc_emails.include?(email)
      end
      failure_count = email_failures.count - regret_failure_count
      if failure_count != object.failure_count
        object.failure_count = failure_count
        object.save
      end
    rescue Exception => e
      Rails.logger.error e.backtrace.join("\n")
      Rails.logger.error e.message
      private_email_failure? ? render_errors(res_hash) : (return res_hash)
    ensure
      render :partial => "fetch_errored_email_details", :locals => {:to_list => @to_list, :cc_list => @cc_list, :ticket_display_id => @ticket.display_id, :admin_emails => play_god_admin_emails} unless private_email_failure?
    end

    def suppression_list_alert
      dropped_address = params['drop_email']
      if dropped_address.present?
        Helpdesk::TicketNotifier.send_later(:suppression_list_alert, current_user, dropped_address, @item.display_id)
        private_email_failure? ? (head 204) : (render :json => { :message => "success"})
      else
        private_email_failure? ? render_errors(DEFAULT_RET_HASH): (render :json => { :message => "failure" })
      end
    end

    def new_activities(params, ticket, type, archive = false)
      res_hash = DEFAULT_RET_HASH.clone
      return res_hash if !ACTIVITIES_ENABLED
      begin
        $activities_thrift_transport.open()
        client    = ::HelpdeskActivities::TicketActivities::Client.new($activities_thrift_protocol)
        act_param = ::HelpdeskActivities::TicketDetail.new
        act_param.account_id = Account.current.id
        act_param.object     = "ticket"
        act_param.object_id  = ticket.display_id
        act_param.event_type = ::HelpdeskActivities::EventType::ALL
        act_param.comparator = ActivityConstants::LESS_THAN
        act_param.shard_name = ActiveRecord::Base.current_shard_selection.shard
        if params[:since_id].present?
          act_param.range_key  = params[:since_id].to_i
          act_param.comparator = ActivityConstants::GREATER_THAN
        elsif params[:before_id].present?
          act_param.range_key  = params[:before_id].to_i
        end
        limit    = params[:limit].present? ? params[:limit].to_i : ActivityConstants::QUERY_UI_LIMIT
        limit    = (limit < ActivityConstants::QUERY_MAX_LIMIT) ? limit : ActivityConstants::QUERY_MAX_LIMIT
        response = client.get_activities(act_param, limit)
        if response.error_message.present?
          return res_hash
        end

        # for querying
        query_hash = response.members.present? ? JSON.parse(response.members).symbolize_keys : {}
        data_hash  = parse_query_hash(query_hash, ticket, archive)
        activities = filter_ticket_data(response.ticket_data)
        filtered_count = response.ticket_data.count - activities.count
        parse_notes data_hash[:notes]
        act_arr    = []
        activities.each do |act|
          begin
            activity = ActivityParser.new(act, data_hash, ticket, type)
            act_arr << activity.safe_send("get_#{type}")
          rescue => e
            Rails.logger.error "#{e} Exception in parse activity #{JSON.parse(act.content)}"
            dev_notification("Error in parse activity",
                             { :exception => e.to_s,
                               :content => act.content,
                               :trace => e.backtrace.join("\n")
                               })
            NewRelic::Agent.notice_error(e, {:description => "Exception in parse activity"})
            next
          end
        end
        res_hash = {
          :activity_list => act_arr
        }
        res_hash.merge!({:total_count => response.total_count - filtered_count}) if response.total_count.present?
      rescue Exception => e
        Rails.logger.error e.backtrace.join("\n")
        Rails.logger.error e.message
        dev_notification("Error in fetching and processing activites",
                         { :exception    => e.to_s,
                           :content     => e.message,
                           :account_id  => Account.current.id,
                           :display_id  => ticket.display_id,
                           :trace       => e.backtrace.join("\n")})
        NewRelic::Agent.notice_error(e, {:description => "Error in fetching and processing activites"})
      ensure
        $activities_thrift_transport.close()
        return res_hash
      end
    end

    def fetch_activities(params, ticket, archive = false)
      $activities_thrift_transport.open()
      client    = ::HelpdeskActivities::TicketActivities::Client.new($activities_thrift_protocol)
      act_param = ::HelpdeskActivities::TicketDetail.new
      act_param.account_id = Account.current.id
      act_param.object     = "ticket"
      act_param.object_id  = ticket.display_id
      act_param.event_type = ::HelpdeskActivities::EventType::ALL
      act_param.comparator = ActivityConstants::LESS_THAN
      act_param.shard_name = ActiveRecord::Base.current_shard_selection.shard
      if params[:since_id].present?
        act_param.range_key  = params[:since_id].to_i
        act_param.comparator = ActivityConstants::GREATER_THAN
      elsif params[:before_id].present?
        act_param.range_key  = params[:before_id].to_i
      end
      limit    = params[:limit].present? ? params[:limit].to_i : ActivityConstants::QUERY_UI_LIMIT
      limit    = (limit < ActivityConstants::QUERY_MAX_LIMIT) ? limit : ActivityConstants::QUERY_MAX_LIMIT
      response = client.get_activities(act_param, limit)
      if response.error_message.present?
        return false
      end

      return response

    rescue Exception => e
      Rails.logger.error e.backtrace.join("\n")
      Rails.logger.error e.message
      dev_notification("Error in fetching and processing activites",
                       { :exception    => e.to_s,
                         :content     => e.message,
                         :account_id  => Account.current.id,
                         :display_id  => ticket.display_id,
                         :trace       => e.backtrace.join("\n")})
      return false
    ensure
      $activities_thrift_transport.close()
    end

  private
    def filter_ticket_data(ticket_data)
      ticket_data.select { |hash| hash.kind != 7 } #ticket summary
    end

    def play_god_admin_emails
      agents = current_account.technicians.select("name, email, privileges")
      admin_count = 0
      agents.inject([]) do |result, agent|
        return result if admin_count > 20
        if agent.privilege?(:admin_tasks)
          admin_count += 1
          hash = {
            "name"  => agent.name,
            "email" => agent.email
          }
          result << hash
        end
        result
      end
    end

    def private_email_failure?
      params[:version] == "private"
    end

    def get_object_activities object
      $activities_thrift_transport.open()
      client = ::HelpdeskActivities::TicketActivities::Client.new($activities_thrift_protocol)
      activity_params = ::HelpdeskActivities::TicketDetail.new
      activity_params.account_id = current_account.id
      activity_params.object     = "ticket"
      activity_params.object_id  = @ticket.display_id
      activity_params.event_type = ::HelpdeskActivities::EventType::ALL
      activity_params.comparator = ActivityConstants::EQUAL_TO
      activity_params.shard_name = ActiveRecord::Base.current_shard_selection.shard
      activity_params.range_key  = object.dynamodb_range_key
      response = client.get_activities(activity_params, 1)
    ensure
      $activities_thrift_transport.close()
      response
    end

    def parse_query_hash(query_hash, ticket, archive)
      obj_hash = {}
      query_hash.each do |key, value|
        case key
        when :status_ids
          obj_hash[:status_name] = Helpdesk::TicketStatus.status_objects_from_cache(Account.current).map { |status|
            [status.status_id, Helpdesk::TicketStatus.translate_status_name(status, 'name')]
          }.to_h
        when :user_ids
          obj_hash[:users]  = fetch_user_and_its_parent(query_hash[:user_ids])
        when :ticket_ids
          obj_hash[:tickets]= Account.current.tickets.select("display_id, subject").where(:display_id => query_hash[:ticket_ids]).collect {|x| [x.display_id, x.subject]}.to_h
        when :rule_ids
          obj_hash[:rules]  = Account.current.account_va_rules.select("id, name").where(:id => query_hash[:rule_ids]).collect {|x| [x.id, x.name]}.to_h
        when :note_ids
          obj_hash[:notes] = archive ? prefetch_archive_notes_for_v2(ticket, query_hash[:note_ids]) :
            prefetch_notes_for_v2(ticket, query_hash[:note_ids])
        end
      end
      obj_hash
    end

    def fetch_user_and_its_parent(user_ids)
      users = Account.current.all_users.preload(:avatar).where(:id => user_ids).to_a
      parent_id = []
      users.each do |user|
        parent =  user.parent_id
        parent_id << parent if !user_ids.include?(parent) and !parent.zero?
      end
      users += Account.current.users.preload(:avatar).where(:id => parent_id).to_a unless parent_id.blank?
      users.collect{|user| [user.id, user]}.to_h
    end

    def prefetch_notes_for_v2(ticket, note_ids)
      options = [:notable, :schema_less_note, :note_body]
      options << (Account.current.new_survey_enabled? ? {:custom_survey_remark =>
                                                         {:survey_result => [:survey_result_data, :agent, {:survey => :survey_questions}]}} : :survey_remark)
      options << :fb_post if ticket.facebook?
      options << :tweet   if ticket.twitter?
      note_hash = ticket.notes.preload(options).where(:id => note_ids).collect{|note| [note.id, note]}.to_h
      build_notes_last_modified_user_hash(note_hash.values)
      note_hash
    end

    def prefetch_archive_notes_for_v2(ticket, note_ids)
      options = [{:user => :avatar}]
      options << :fb_post if ticket.facebook?
      options << :tweet if ticket.twitter?
      current_shard = ActiveRecord::Base.current_shard_selection.shard.to_s
      if(ArchiveNoteConfig[current_shard] && (ticket.id <= ArchiveNoteConfig[current_shard].to_i))
        note_hash = Helpdesk::ArchiveNote.includes(options).where(:note_id => note_ids).collect{|note| [note.note_id, note]}.to_h
        build_notes_last_modified_user_hash(note_hash.values)
      else
        options << :schema_less_note << :note_body << :attachments
        note_hash = Helpdesk::Note.includes(options).where(:id => note_ids).collect{|note| [note.id, note]}.to_h
        build_notes_last_modified_user_hash(note_hash.values)
      end
      note_hash
    end

    def parse_notes(notes)
      notes.select { |key,value| value.source != Account.current.helpdesk_sources.note_source_keys_by_token['summary']}
    end

    def dev_notification(subj, message, topic = nil)
      notification_topic = topic || SNS["activities_notification_topic"]
      DevNotification.publish(notification_topic, subj, message.to_json)
    end
  end
end
