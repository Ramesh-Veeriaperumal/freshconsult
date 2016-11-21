module Helpdesk::Activities
  module ActivityMethods
    include HelpdeskActivities::TicketActivities
    include Helpdesk::NotePropertiesMethods

    DEFAULT_STATUS_KEYS = Helpdesk::Ticketfields::TicketStatus::DEFAULT_STATUSES.keys
    def new_activities(params, ticket, type, archive = false)
      res_hash = {
        :error => "Internal server error",
        :error_code => "400"
      }
      return res_hash if !(ACTIVITIES_ENABLED and Account.current.features?(:activity_revamp))
      begin
        response = fetch_activities(params, ticket, type, archive)

        # for querying
        query_hash = response.members.present? ? JSON.parse(response.members).symbolize_keys : {}
        data_hash  = parse_query_hash(query_hash, ticket, archive)
        activities = response.ticket_data
        
        act_arr    = []
        activities.each do |act|
          begin
            activity = ActivityParser.new(act, data_hash, ticket, type)
            act_arr << activity.send("get_#{type}")
          rescue => e
            Rails.logger.error "#{e} Exception in parse activity #{JSON.parse(act.content)}"
            dev_notification("Error in parse activity", 
              { :exception => e.to_s, 
                :content => act.content, 
                :trace => e.backtrace.join("\n")
              })
            next
          end
        end
        res_hash = {
          :activity_list => act_arr
        }
        res_hash.merge!({:total_count => response.total_count}) if response.total_count.present?
      rescue Exception => e
        Rails.logger.error e.backtrace.join("\n")
        Rails.logger.error e.message
        dev_notification("Error in fetching and processing activites", 
          { :exception    => e.to_s, 
            :content     => e.message,
            :account_id  => Account.current.id,
            :display_id  => ticket.display_id,
            :trace       => e.backtrace.join("\n")})
      ensure
        $thrift_transport.close()
      end
    end
    
    def fetch_activities(params, ticket, type, archive = false)
      $thrift_transport.open()
      client    = ::HelpdeskActivities::TicketActivities::Client.new($thrift_protocol)
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
      $thrift_transport.close()
    end

  private
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
          obj_hash[:notes]  = archive ? prefetch_archive_notes_for_v2(ticket, query_hash[:note_ids]) :
                              prefetch_notes_for_v2(ticket, query_hash[:note_ids])                      
        end
      end
      obj_hash
    end

    def fetch_user_and_its_parent(user_ids)
      users = Account.current.all_users.where(:id => user_ids).to_a
      parent_id = []
      users.each do |user|
        parent =  user.parent_id
        parent_id << parent if !user_ids.include?(parent) and !parent.zero?
      end
      users += Account.current.users.where(:id => parent_id).to_a
      users.collect{|user| [user.id, user]}.to_h
    end

    def prefetch_notes_for_v2(ticket, note_ids)
      options = [:notable, :schema_less_note, :note_old_body]
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
        note_hash = Helpdesk::Note.includes(options).where(:id => note_ids).collect{|note| [note.id, note]}.to_h
        build_notes_last_modified_user_hash(note_hash.values)
      end
      note_hash
    end

    def dev_notification(subj, message, topic = nil)
      notification_topic = topic || SNS["activities_notification_topic"]
      DevNotification.publish(notification_topic, subj, message.to_json)
    end
  end
end
