module Helpdesk::Activities
  class ActivityParser
    include TicketConstants
    include ActivityConstants
    include ApplicationHelper
    include Rails.application.routes.url_helpers    #for rails routes

    attr_accessor :act_performed_time, :act_performer, :act_ticket, :act_content,
                  :act_summary, :act_activity, :act_type, :act_event_type,
                  :act_suffix, :act_rule_id, :act_summary_text
    DONT_CARE_VALUE = "*"
    TIME_FORMAT_FOR_TIMESHEET = "%a, %-d %b, %Y"
    ACTIVITY = "activities.tickets.%{value}.%{suffix}"
    TYPE = {
        :tkt_activity   => "new",
        :dashboard      => "dashboard",
        :json           => "new",
        :test_json      => "new"
    }

    def initialize(ticketdata, data_hash, ticket, type)
      @act_data_hash      = data_hash
      @type               = type
      @act_ticket         = ticket
      @invalid_act        = false     # to denote, the activity will be show in UI or not
      @act_suffix         = TYPE[type]
      @current_user       = User.current
      @act_summary        = ticketdata.summary.nil? ? nil : ticketdata.summary.to_i
      @email_failures     = JSON.parse(ticketdata.email_failures.gsub('=>', ':')) unless ticketdata.email_failures == "null"
      @act_activity       = {
                            :new  => [], :set  => [], :edit => [], :custom => [], 
                            :misc => [], :rule => {}, :text => [], :note   => [],
                            :scenario => []}
      @act_content        = JSON.parse(ticketdata.content).deep_symbolize_keys
      @act_performed_time = ticketdata.published_time.to_i
      @act_event_type     = ticketdata.event_type.to_s == "system" ? 0 : 1
      activity_hash       = @act_content[:system_changes].present? ? system_changes(@act_content[:system_changes]) : @act_content
      set_performer(ticketdata.actor.to_i)
      set_activities(activity_hash)
    end

    def get_tkt_activity
      activity_params = {
        :performer      => @act_performer,
        :performed_time => @act_performed_time,
        :event_type     => @act_event_type,
        :summary        => get_summary,
        :activity_arr   => build_activity,
        :activity       => @act_activity,
        :invalid        => @invalid_act
      }
      Helpdesk::Activities::Activity.new(activity_params)
    end

    def get_json
      activity_json = {:performed_time => get_formatted_time_for_activity(@act_performed_time)}
      act      = []
      user_obj = []
      user_obj.push({ "id" => @act_performer.id, "name" => @act_performer.name, "email" => @act_performer.email, 
                           "agent" => @act_performer.helpdesk_agent })

      if new_ticket?
        act.push(render_string(get_string_name("new_ticket")))
      elsif outbound_email?
        act.push(render_string(get_string_name("new_outbound")))
      elsif note?
        activity_json.merge!({ :note_content =>  @act_activity[:note].first[0].body,  # @act_activity[:note] => [note_object, note_properties]
                      :private => @act_activity[:note].first[0].private})
      end
      @act_activity.each do |key, value|
        act += value if ![:note, :rule].include?(key)
      end
      activity_json.merge!({:performer => user_obj, :activity => act})
      {:ticket_activity => activity_json}
    end

    def get_test_json
      # for time
      activity_json = {:performed_time => get_formatted_time_for_activity(@act_performed_time)}
      # for event type
      activity_json.merge!({:event_type => (@act_event_type.zero? ? "system" : "user")})
      # summary
      activity_json.merge!({:summary => get_summary})
      # for user details
      if @act_performer.present?
        user_hash = { "user_id" => @act_performer.id, "name" => @act_performer.name, "email" => @act_performer.email, 
                             "agent" => @act_performer.helpdesk_agent}
        activity_json.merge!({:performer => user_hash})
      end
      # for rule
      if @act_activity[:rule].present?
        rule = @act_activity[:rule]
        rule_hash = {"rule_type" => rule[:type_name], "rule_id" => rule[:id], "rule_name" => rule[:name]}
        activity_json.merge!({:rule => rule_hash})
      end
      # for note
      if @act_activity[:note].present?
        note_obj = @act_activity[:note].first[0]
        note_hash = { :note_content => note_obj.body,  # @act_activity[:note] => [note_object, note_properties]
                      :to_emails    => note_obj.to_emails,
                      :cc_emails    => note_obj.cc_emails,
                      :bcc_emails   => note_obj.bcc_emails,
                      :private      => note_obj.private}
        activity_json.merge!({:note => note_hash})             
      end
      # for all activities
      activity_arr = build_activity
      # seperate activity
      activity_json.merge!({:activity => activity_arr})
      {:ticket_activity => activity_json}
    end

    def get_dashboard

    end

    private

    def get_summary
      if SUMMARY_FOR_TOKEN.has_key?(@act_summary)
        str = "activities.tag.#{SUMMARY_FOR_TOKEN[@act_summary]}"
        params =  @act_summary_text.present? ? {:value => escapeHTML(CGI::unescapeHTML("#{@act_summary_text}"))} : {}
        render_string(str, params)
      else
        nil
      end
    end

    def build_activity
      activity_str = []
      if new_ticket? or outbound_email? or split_ticket_target?
        str = if @act_activity[:new].present?
          "#{@act_activity[:new]}"
        elsif new_ticket?
          render_string(get_string_name("new_ticket"))
        elsif outbound_email?
          render_string(get_string_name("new_outbound"))
        end
        activity_str << str
      end
      activity_str += @act_activity[:scenario] if @act_activity[:scenario].present?
      @act_activity.each do |key, value|
        case key
        when :set
          if @act_activity[:set].present?
            activity_str << "#{render_string("activities.set")} #{@act_activity[:set].join(', ')}"
          end
        when :custom 
          if @act_activity[:custom].present?
            activity_str << "#{render_string("activities.set")} #{@act_activity[:custom].join(', ')}"
          end          
        when :edit
          if @act_activity[:edit].present?
            params = {:fields => @act_activity[:edit].join(', ')}
            str    = get_string_name("ticket_edit")
            activity_str << render_string(str, params)
          end
        when :misc
          activity_str += @act_activity[:misc] if @act_activity[:misc].present?
        when :text
          if @act_activity[:text].present?
            str    = get_string_name("custom_text_field_change")          
            params = {:text_fields => @act_activity[:text].join(', ')}
            activity_str << render_string(str, params)
          end
        end
      end
      activity_str
    end

    def set_performer(actor)
      @act_performer = get_user(actor) if !actor.zero?
    end

    def get_performed_time(published_time)
      Time.zone.at(published_time)
    end

    def system_changes(value)
      @act_rule_id = value.keys.first.to_s.to_i
      value.values.first
    end

    def set_activities(activity_hash)
      activity_hash.each do |attribute, value|
        if respond_to?("#{attribute}", true)
          send(attribute, value)
        else
          custom_fields(attribute, value[1])
        end
      end
    end
    
    def get_formatted_time_for_activity(time_in_seconds, time_format = nil)
      if time_format.nil?
        time_in_seconds /= TIME_MULTIPLIER
        time_format = Account.current ? Account.current.date_type(:short_day_with_time) : "%a, %-d %b, %Y at %l:%M %p"
      end
      date_time = Time.zone.at(time_in_seconds)
      date_time.strftime(time_format)
    end

    # default fields
    def status(value)
      str  = get_string_name("status_change")
      text = @act_data_hash[:status_name][value[0].to_i]
      text =  value[1] if text.blank?
      @act_summary_text = text if @act_summary == TICKET_ACTIVITY_KEYS_BY_TOKEN[:status]
      @act_activity[:set] << render_string(str,
            {:status_name => escapeHTML("#{text}")})
    end

    def delete_status(value)
      str  = get_string_name("property_delete")
      deleted_property_value = value[0]
      property_value = @act_data_hash[:status_name][value[1].to_i]
      @act_activity[:set] << render_string(str,
            {:property => "#{render_string("activities.status")}", 
              :deleted_property_value => escapeHTML("#{deleted_property_value}"), 
              :property_value => escapeHTML("#{property_value}")})
    end

    def priority(value)
      str  = get_string_name("priority_change")
      text = TicketConstants.translate_priority_name(value[1].to_i)
      @act_summary_text = text if @act_summary == TICKET_ACTIVITY_KEYS_BY_TOKEN[:priority]
      @act_activity[:set] << render_string(str, 
            {:priority_name => escapeHTML("#{text}")})
    end

    def source(value)
      str = get_string_name("source_change")
      @act_activity[:set] << render_string(str, 
            {:source_name =>"#{TicketConstants.translate_source_name(value[1].to_i)}"})
    end

    def ticket_type(value)
      params = if value[1].blank?
        {:ticket_type => "#{render_string("activities.none")}"}
      else
        {:ticket_type => escapeHTML("#{value[1]}")}
      end
      str = get_string_name("ticket_type_change")
      @act_activity[:set] << render_string(str, params)
    end

    def responder_id(value)
      params = if value[1].blank?
        {:responder_path => "#{render_string("activities.none")}"}
      else
        user = get_user(value[1].to_i)
        return if user.blank?
        {:responder_path => "#{build_url(user.name, user_path(user))}"}
      end
      str = get_string_name("assigned")
      @act_activity[:set] << render_string(str, params)
    end

    def delete_agent(value)
      str  = get_string_name("delete_agent")
      user = get_user(value[0].to_i)
      return if user.blank?
      @act_activity[:misc] << render_string(str, 
        { :property => "#{render_string("activities.agent")}",
          :responder_path => "#{build_url(user.name, user_path(user))}"})
    end

    def internal_agent_id(value)
      params = if value[1].blank?
        {:responder_path => "#{render_string("activities.none")}"}
      else
        user = get_user(value[1].to_i)
        return if user.blank?
        {:responder_path => "#{build_url(user.name, user_path(user))}"}
      end
      str = get_string_name("internal_agent")
      @act_activity[:set] << render_string(str, params)      
    end

    def delete_internal_agent(value)
      str  = get_string_name("delete_agent")
      user = get_user(value[0].to_i)
      return if user.blank?
      params = {:property => "#{render_string("activities.internal_agent")}",
                :responder_path => "#{build_url(user.name, user_path(user))}"}
      @act_activity[:misc] << render_string(str, params)
    end

    def requester_id(value)
      str  = get_string_name("requester_change")
      user = get_user(value[1].to_i)
      return if user.blank?
      @act_activity[:set] << render_string(str, {:requester_name => "#{build_url(user.name, user_path(user))}"}) if user
    end

    def rel_tkt_link(value)
      str = get_string_name("rel_tkt_link")
      @act_activity[:misc] << render_string(str, { :tracker_ticket_path => build_ticket_url(value.first.to_i)})
    end

    def rel_tkt_unlink(value)
      str = get_string_name("rel_tkt_unlink")
      @act_activity[:misc] << render_string(str, { :tracker_ticket_path => build_ticket_url(value.first.to_i)})    
    end

    def tracker_link(value)
      str = get_string_name("tracker_link")
      params = {
        :related_tickets_count => pluralize(value.count,
          I18n.t("ticket.link_tracker.rlt_ticket_singular"),
          I18n.t("ticket.link_tracker.rlt_ticket_plural")),
        :related_ticket_path => multiple_tickets_url(value)
      }
      @act_activity[:misc] << render_string(str, params)
    end

    def tracker_unlink(value)
      str = get_string_name("tracker_unlink")
      params = {
        :related_tickets_count => pluralize(value.count,
          I18n.t("ticket.link_tracker.rlt_ticket_singular"),
          I18n.t("ticket.link_tracker.rlt_ticket_plural")),
        :related_ticket_path => multiple_tickets_url(value)
      }
      @act_activity[:misc] << render_string(str, params)
    end

    def tracker_unlink_all(value)
      str = get_string_name("tracker_unlink_all")
      params = {
        :related_tickets_count => pluralize(value.to_i,
          I18n.t("ticket.link_tracker.rlt_ticket_singular"),
          I18n.t("ticket.link_tracker.rlt_ticket_plural")),
        :all => (value.to_i == 1) ? "" : "all "
      }
      @act_activity[:misc] << render_string(str, params)
    end

    def tracker_reset(value)
      str = get_string_name("tracker_reset")
      @act_activity[:misc] << render_string(str)
    end

    # confirm all the text from vikram
    def assoc_parent_tkt_link(value)
      str = get_string_name("assoc_parent_tkt_link")
      @act_activity[:misc] << render_string(str, { :child_ticket_path => build_ticket_url(value.first.to_i)})
    end

    def assoc_parent_tkt_unlink(value)
      str = get_string_name("assoc_parent_tkt_unlink")
      params = {
        :child_tickets_count => pluralize(value.count,
          I18n.t("ticket.parent_child.child_tkt_singular"),
          I18n.t("ticket.parent_child.child_tkt_plural")),
        :child_ticket_path => multiple_tickets_url(value)
      }
      @act_activity[:misc] << render_string(str, params)
    end

    def child_tkt_link(value)
      str = get_string_name("child_tkt_link")
      @act_activity[:misc] << render_string(str, { :assoc_prt_tkt_path => build_ticket_url(value.first.to_i)})
    end

    def child_tkt_unlink(value)
      str = get_string_name("child_tkt_unlink")
      @act_activity[:misc] << render_string(str, { :assoc_prt_tkt_path => build_ticket_url(value.first.to_i)})
    end

    def assoc_parent_tkt_open(value)
      @act_activity[:misc] << "#{I18n.t("activities.reopen_ticket")}"
    end

    def group_id(value)
      params = if value[1].blank?
        {:group_name => "#{render_string("activities.none")}"}
      else
        {:group_name => escapeHTML("#{value[1]}")}
      end
      str = get_string_name("group_change")
      @act_activity[:set] << render_string(str, params)
    end

    def delete_group(value)
      str  = get_string_name("property_delete")
      deleted_property_value = escapeHTML("#{value[0]}")
      property_value = "#{render_string("activities.none")}"
      @act_activity[:set] << render_string(str,
            {:property => "#{render_string("activities.group")}", 
              :deleted_property_value => escapeHTML("#{deleted_property_value}"),       
              :property_value => escapeHTML("#{property_value}")})
    end

    def internal_group_id(value)
      params = if value[1].blank?
        {:group_name => "#{render_string("activities.none")}"}
      else
        {:group_name => escapeHTML("#{value[1]}")}
      end
      str = get_string_name("internal_group")
      @act_activity[:set] << render_string(str, params)
    end

    def delete_internal_group(value)
      str    = get_string_name("internal_agent_group_none")
      params = {:property => "#{render_string("activities.group")}",
                :deleted_value => escapeHTML("#{value[0]}")}
      @act_activity[:misc] << render_string(str, params)
    end

    def due_by(value)
      str  = get_string_name("due_date_updated")
      time = formatted_dueby_for_activity(value[1].to_i)
      return if time.blank?
      @act_activity[:set] << render_string(str, {:due_date_updated => escapeHTML("#{time}")})
    end

    def product_id(value)
      params = if value[1].blank?
        {:product_name => "#{render_string("activities.none")}"}
      else
        {:product_name => escapeHTML("#{value[1]}")}
      end
      str = get_string_name("product_change")
      @act_activity[:set] << render_string(str, params)
    end

    def subject(value)
      @act_activity[:edit] << "#{render_string("activities.subject")}"
    end

    def description(value)
      @act_activity[:edit] << "#{render_string("activities.description")}"
    end

    # timesheet
    def timesheet_old(value)
      if value.has_key?(:timer_running)
        timer_running(value)
      else
        time_spent(value)
      end
    end

    def timesheet_create(value)
      params     = build_timesheet_params(value, true)
      prop       = value[:time_spent][1].to_i.zero? ? get_string_name("timesheet_without_time") : get_string_name("timesheet_with_time")
      properties = render_string(prop, params)
      params     = {:timesheet => properties}
      str = if value.has_key?(:timer_running)
        get_string_name("timesheet_timer_start")
      else
        get_string_name("timesheet_create")
      end
      @act_activity[:misc] << render_string(str, params)
    end

    def timesheet_edit(value)
      if value.has_key?(:timer_running)
        params     = build_timesheet_params(value, true)
        prop       = get_string_name("timesheet_with_time")
        properties = render_string(prop, params)
        params     = {:timesheet => properties}
        str        = (value[:timer_running][1] == true ? get_string_name("timesheet_timer_start") : get_string_name("timesheet_timer_stop"))
      else
        prop       = (value[:time_spent][1].to_i.zero? ? get_string_name("timesheet_without_time") : get_string_name("timesheet_with_time"))
        # for old timesheet
        params_old = build_timesheet_params(value, false)
        prop_old   = render_string(prop, params_old)
        # for new timesheet
        params_new = build_timesheet_params(value, true)
        prop_new   = render_string(prop, params_new)
        str        = get_string_name("timesheet_edit")
        params     = {:old_timesheet => prop_old, :new_timesheet => prop_new}
      end
      @act_activity[:misc] << render_string(str, params)
    end

    def timesheet_delete(value)
      params     = build_timesheet_params(value, false)
      prop       = get_string_name("timesheet_with_time")
      properties = render_string(prop, params)
      params     = {:timesheet => properties}
      str        = get_string_name("timesheet_delete")
      @act_activity[:misc] << render_string(str, params)
    end

    def build_timesheet_params(value, flag)
      index  = (flag == true ? 1 : 0)
      params = {}
      params[:billable]   = render_string(get_billable_type(value[:billable][index]))
      user                = get_user(value[:user_id][index].to_i)
      return if user.blank?
      params[:user_path]  = "#{build_url(user.name, user_path(user))}"
      params[:date]       = get_formatted_time_for_activity(value[:executed_at][index].to_i, TIME_FORMAT_FOR_TIMESHEET)
      time_spent          = value[:time_spent][index].to_i
      params[:time_spent] = escapeHTML("#{get_formatted_time(time_spent)}")
      params
    end

    def timer_running(value)
      str = if value[:timer_running][1] == true 
        get_string_name("timesheet.timer_started")
      else
        get_string_name("timesheet.timer_stopped")
      end
      @act_activity[:misc] << render_string(str)
    end

    def time_spent(value)
      str    = get_string_name("timesheet.new")
      @act_activity[:misc] << render_string(str)
    end

    # Tags
    def add_tag(value)
      str = get_string_name("added_tag")
      @act_activity[:misc] << render_string(str, { :tag_name => escapeHTML("#{value.join(', ')}")}) if value.present?
    end

    def remove_tag(value)
      str = get_string_name("removed_tag")
      @act_activity[:misc] << render_string(str, { :tag_name => escapeHTML("#{value.join(', ')}")}) if value.present?
    end

    # Notes
    def add_comment(value)
      str_value = "add_note"
      @act_activity[:misc] << render_string(get_string_name(str_value))
    end

    def note(value)
      note_id = value[:id]
      note    = get_note(note_id.to_i)
      return @invalid_act = true if note.nil?
      ret_arr = [note, value]
      if @email_failures.present?
        @email_failures = @email_failures.reduce Hash.new, :merge
        
        ret_arr << note_email_failures(note.to_emails)
        ret_arr << note_email_failures(note.cc_emails)
      end
      @act_activity[:note] << ret_arr
    end

    def note_email_failures(emails)
      email_errors = @email_failures.select{|email, error| emails.include?(email)}
      email_errors.each{|email,error| email_errors[email] = FAILURE_CATEGORY[error.to_i]}
      email_errors
    end

    # for merge, split, ticket import and round robin
    def activity_type(value)
      if value[:type].present?
        send(value[:type], value) if respond_to?(value[:type], true)
      end
    end

    def ticket_merge_source(value)
      target_ticket = value[:target_ticket_id][0].to_i
      target_ticket_link = build_ticket_url(target_ticket)
      str    = get_string_name("ticket_merge_source")
      params = {:target_ticket => "#{target_ticket_link}"}
      @act_activity[:misc] << render_string(str, params)
    end
    
    def ticket_merge_target(value)
      source_ticket_link = []
      source_ticket = value[:source_ticket_id] # can have multiple values
      source_ticket.each do |x|
        source_ticket_link << build_ticket_url(x.to_i)
      end
      str    = get_string_name("ticket_merge_target")
      params = {:source_ticket_list => "#{source_ticket_link.join(', ')}"}
      @act_activity[:misc] << render_string(str, params)
    end

    def ticket_split_source(value)
      target_ticket = value[:target_ticket_id][0].to_i
      target_ticket_link = build_ticket_url(target_ticket)
      str    = get_string_name("ticket_split_source")
      params = {:target_ticket => "#{target_ticket_link}"}
      @act_activity[:misc] << render_string(str, params)
    end

    def ticket_split_target(value)
      source_ticket = value[:source_ticket_id][0].to_i
      source_ticket_link = build_ticket_url(source_ticket)
      str    = get_string_name("ticket_split_target")
      params = {:source_ticket => "#{source_ticket_link}"}
      @act_activity[:new] << render_string(str, params)
    end

    def ticket_import(value)
      imp_time = get_formatted_time_for_activity(value[:imported_at].to_i * TIME_MULTIPLIER)
      params   = {:imported_time => imp_time}
      str      = get_string_name("ticket_import")
      @act_activity[:misc] << render_string(str, params)
    end

    def round_robin(value)
      user = get_user(value[:responder_id][1].to_i)
      return if user.blank?
      params = {:responder_path => "#{build_url(user.name, user_path(user))}"}
      str = get_string_name("assigned")
      rule_type_name   = "#{render_string("activities.round_robin")}"
      # marking rule type as -1 for round robin
      @act_activity[:rule] = {:type_name => rule_type_name, :name => "", :id=> 0 , :type=> -1, :exists => false}
      @act_activity[:set] << render_string(str, params)
    end

    def shared_ownership_reset(value)
      internal_group_id(value[:internal_group_id]) if value[:internal_group_id].present?
      internal_agent_id(value[:internal_agent_id]) if value[:internal_agent_id].present?
      str = render_string(get_string_name("automation_execution"))
      @act_activity[:set].last.concat(str) if value[:internal_group_id].present? or value[:internal_agent_id].present?
    end

    # System rule
    def rule(value)    
      rule_name   = escapeHTML(get_rule_name(@act_rule_id))
      rule_type   = RULE_LIST[value[0].to_i]
      rule_exists = rule_name.present? ? true : false
      rule_name   = escapeHTML(value[1]) if !rule_exists
      rule_type_name   = "#{render_string("activities.#{rule_type}")}"
      @act_activity[:rule] = {:type_name => rule_type_name, :name => rule_name, :id=> @act_rule_id, :type=> value[0].to_i, :exists => rule_exists}
    end

    # scenario automation
    def execute_scenario(value)
      str            = get_string_name("execute_scenario")
      params         = {:scenario_name => escapeHTML("#{value[1]}")}
      @act_activity[:scenario] << render_string(str, params)
    end

    # watchers
    def watcher(value)
      watchr = []
      watch_arr = value[:user_id]
      if watch_arr[1].to_i.zero?
        str    = get_string_name("removed_watcher")
        user   = get_user(watch_arr[0].to_i)
      else
        str    = get_string_name("added_watcher")
        user   = get_user(watch_arr[1].to_i)
      end
      watchr << "#{build_url(user.name, user_path(user))}" if user.present?
      return if watchr.blank?
      params = {:watcher_list => "#{watchr}"}
      @act_activity[:misc] << render_string(str, params)
    end

    def add_watcher(value)
      watcher_arr = build_user_arr(value)
      @invalid_act    = watcher_arr.count.zero?
      str         = get_string_name("added_watcher")
      @act_activity[:misc] << render_string(str, {:watcher_list => "#{watcher_arr.join(', ')}"})  if watcher_arr.present?
    end

    def add_a_cc(value)
      str    = get_string_name("add_cc")
      @act_activity[:misc] << render_string(str, {:cc_list => escapeHTML("#{value.join(', ')}")}) if value.present?
    end

    def deleted(value)
      str = if value[1] == true
        get_string_name("deleted")
      else
        get_string_name("restored")
      end
      @act_activity[:misc] << render_string(str)
    end

    def email_to_requester(value)
      str    = get_string_name("email_to_requester")
      user   = get_user(value[0].to_i)
      return if user.blank?
      @act_activity[:misc] << render_string(str, {:requester_name => "#{build_url(user.name, user_path(user))}"})
    end

    def email_to_group(value)
      str = get_string_name("email_to_group")
      @act_activity[:misc] << render_string(str, {:group_list => escapeHTML("#{value.join(', ')}")}) if value.present?
    end

    def email_to_agent(value)
      agent_arr   = build_user_arr(value)
      @invalid_act    = agent_arr.count.zero?
      str         = get_string_name("email_to_agent")
      @act_activity[:misc] << render_string(str, {:agent_list => "#{agent_arr.join(', ')}"})  if agent_arr.present?      
    end

    def spam(value)
      str = if value[1] == true
        get_string_name("spam")
      else
        get_string_name("unspam")
      end
      @act_activity[:misc] << render_string(str)
    end

    def remove_group(value)
      str    = get_string_name("remove_group")
      params = {:group_name => escapeHTML("#{value[0]}"), :status_name => escapeHTML("#{value[1]}")}
      @act_activity[:misc] << render_string(str, params)
    end

    def remove_agent(value)
      str  = get_string_name("remove_agent")
      user = get_user(value[0].to_i)
      return if user.blank?
      params = {:responder_path => "#{build_url(user.name, user_path(user))}", :group_name => escapeHTML("#{value[1]}")}
      @act_activity[:misc] << render_string(str, params)
    end

    def remove_status(value)
      str    = get_string_name("internal_agent_group_none")
      params = {:property => "#{render_string("activities.status")}", 
                :deleted_value => escapeHTML("#{value[0]}")}      
      @act_activity[:misc] << render_string(str, params)
    end

    # custom checkboxes
    def checked(value)
      str    = get_string_name("checkbox_checked")
      params = {:checkbox_list => escapeHTML("#{value.join(', ')}")}
      @act_activity[:misc] << render_string(str, params)
    end

    def unchecked(value)
      str    = get_string_name("checkbox_unchecked")
      params = {:checkbox_list => escapeHTML("#{value.join(', ')}")}
      @act_activity[:misc] << render_string(str, params)
    end

    # custom fields
    def custom_fields(field_name, value)
      if text_field?(value)    # text fields
        @act_activity[:text] << field_name.to_s
      else
        params = if value.blank?
          {:field_value => "#{render_string("activities.none")}"}  
        else
          {:field_value => escapeHTML("#{value}")}
        end
        params[:field_name] = escapeHTML("#{field_name.to_s}")
        str = get_string_name("custom_field_change")
        @act_activity[:custom] << render_string(str, params)
      end
    end

    def archive(value)
      str = get_string_name("archive")
      @act_activity[:misc] << render_string(str)
    end

    # helper functions
    def render_string(str, params = {})
      I18n.t(str, params)
    end

    def escapeHTML(value)
      RailsFullSanitizer.sanitize(value)
    end

    def build_ticket_url(ticket_id)
      ticket_subject = @act_data_hash[:tickets][ticket_id]
      title =  ticket_id
      if ticket_subject.present?
        title = "#{ticket_subject}(##{ticket_id})"
      end
      build_url(title, helpdesk_ticket_path(ticket_id))      
    end

    def build_url(title, url)
      title = escapeHTML("#{title}")
      @act_type == :json ? "#{title}" : "<a href='#{url}'>#{title}</a>"
    end

    def build_user_arr(value)
      user_arr = []
      value.each do |user_id|
        user = get_user(user_id.to_i)
        user_arr << build_url(user.name, user_path(user)) if user.present?
      end
      user_arr
    end

    def get_string_name(value)
      ACTIVITY % {:value => value, :suffix => @act_suffix }
    end

    def get_formatted_time(seconds)
      hh = (seconds/3600).to_i
      mm = ((seconds % 3600)/60.to_f).round
      hh.to_s.rjust(2,'0') + ":" + mm.to_s.rjust(2,'0')
    end

    def get_user(user_id)
      user   = @act_data_hash[:users][user_id]
      if user.blank?
        @invalid_act = true
        return
      else
        parent = user.parent_id.zero? ? nil : @act_data_hash[:users][user.parent_id]
        parent.nil? ? user : parent
      end
    end

    def get_rule_name(rule_id)
      @act_data_hash[:rules][rule_id]
    end

    def get_note(note_id)
      @act_data_hash[:notes][note_id]
    end

    def get_billable_type(billable)
      billable ? "activities.tag.timesheet.billable" : "activities.tag.timesheet.non_billable"
    end

    def text_field?(value)
      value.to_s == DONT_CARE_VALUE
    end

    def system_event?
      @act_performer.zero?
    end

    def user_event?
      !@act_performer.zero?
    end

    def ticket?
      @object == "ticket"
    end

    def new_ticket?
      @act_summary == TICKET_ACTIVITY_KEYS_BY_TOKEN[:new_ticket]
    end

    def outbound_email?
      @act_summary == TICKET_ACTIVITY_KEYS_BY_TOKEN[:outbound_email]
    end

    def split_ticket_target?
      @act_summary ==  TICKET_ACTIVITY_KEYS_BY_TOKEN[:ticket_split_target]
    end

    def activity_summary
      @act_summary
    end

    def current_account
      Account.current
    end

    def account
      @account ||= Account.current
    end

    def note?
      @act_summary ==  TICKET_ACTIVITY_KEYS_BY_TOKEN[:conversation] || @act_activity[:note].present?
    end

    def multiple_tickets_url(value)
      value.map do |v|
        title = "##{v.to_i}"
       "#{build_url(title, helpdesk_ticket_path(v.to_i))}"
      end.join(', ')
    end
  end
end
