module Tickets
  class ActivityDecorator < ApiDecorator
    include ActivityConstants

    delegate :published_time, :actor, :summary, :event_type, to: :record

    SPECIAL_ACTION_IDENTIFIER = 'activity_type'.freeze

    SPECIAL_ACTIONS = [
      :ticket_merge_source,
      :ticket_merge_target,
      :ticket_split_source,
      :ticket_split_target,
      :ticket_import,
      :round_robin
    ].freeze

    PROPERTY_ACTIONS = [
      :subject,
      :description,
      :status,
      :priority,
      :source,
      :ticket_type,
      :responder_id,
      :group_id,
      :requester_id,
      :due_by,
      :product_id,
      :custom_fields,
      :checked,
      :unchecked,
      :internal_agent_id,
      :internal_group_id,
      :thank_you_note
    ].freeze

    ARRAY_CONTENT_TYPES = [
      :add_tag, :remove_tag, :add_a_cc,
      :email_to_requester, :email_to_group, :email_to_agent,
      :tracker_link, :tracker_unlink, :assoc_parent_tkt_unlink
    ].freeze

    CONTENT_LESS_TYPES = [:spam, :archive, :deleted, :tracker_reset, :assoc_parent_tkt_open].freeze

    ACTION_TYPE_MAPPING = {
      rel_tkt_link:            :ticket_linked,
      rel_tkt_unlink:          :ticket_unlinked,
      tracker_link:            :tracker_linked,
      tracker_unlink:          :tracker_unlinked,
      child_tkt_link:          :child_ticket_linked,
      child_tkt_unlink:        :child_ticket_unlinked,
      assoc_parent_tkt_open:   :parent_ticket_reopened,
      assoc_parent_tkt_link:   :parent_ticket_linked,
      assoc_parent_tkt_unlink: :parent_ticket_unlinked,
      watcher:                 :add_watcher
    }.freeze

    def initialize(record, options)
      super(record)
      @query_data_hash = options[:query_data_hash]
      @ticket = options[:ticket]
    end

    def to_hash
      {
        id: published_time, # Just for the sake of giving an id
        performer: performer,
        highlight: summary.nil? ? nil : summary.to_i,
        ticket_id: @ticket.display_id,
        performed_at: parse_activity_time(published_time),
        actions: safe_send("#{performer_type}_actions").reject(&:empty?)
      }
    end

    private

      def performer
        performing_hash = safe_send("performing_#{performer_type}")
        return if performing_hash.nil?
        performer_hash = {}
        performer_hash[:type] = performer_type
        performer_hash[:user_id] = actor if performer_type == :user
        performer_hash[performer_type] = performing_hash if performing_hash.present?
        performer_hash
      end

      def performing_user
        user = get_user(actor)
        user_hash(user) || {} if user.present?
      end

      def user_hash(user)
        ContactDecorator.new(user, {}).to_hash unless user.agent? || @ticket.requester_id == user.id
      end

      def performing_system
        if activity_content[:system_changes].present?
          performing_rule(activity_content[:system_changes])
          {
            id: @rule_id,
            type: RULE_LIST[@rule_type],
            name: @rule_name,
            exists: rule_exists?
          }
        elsif round_robin?(activity_content)
          {
            id: 0,
            type: RULE_LIST[-1],
            name: '',
            exists: true
          }
        else # Fallback: few system performed activities does not have rule associated with it.
          {
            id: 0,
            type: 'default_system',
            name: '',
            exists: true
          }
        end
      end

      def avatar_hash(avatar)
        return nil unless avatar.present?
        AttachmentDecorator.new(avatar).to_hash.merge(thumb_url: avatar.attachment_url_for_api(true, :thumb))
      end

      def performer_type
        event_type.to_sym
      end

      def user_actions
        action_array
      end

      def system_actions
        action_array(activity_content_hash.reject { |k| k == :rule })
      end

      def parse_activity_time(time_in_seconds, multiplier = true)
        time_in_seconds /= TIME_MULTIPLIER if multiplier
        Time.at(time_in_seconds).utc
      end

      def action_array(items = activity_content)
        result_hash = items.collect do |key, value|
          result = {}
          type, content = action_content(key, value)
          result[type] = content if content.present? || CONTENT_LESS_TYPES.include?(key)
          result
        end
        result = result_hash.group_by(&:keys).map do |key, value|
          content = parsed_content(key.first, value)
          type = key.first
          action_hash = {}
          if type
            action_hash[:type] = type
            action_hash[:content] = content if content
          end
          action_hash
        end
        result
      end

      def parsed_content(type, value)
        if ARRAY_CONTENT_TYPES.include?(type)
          value.flat_map(&:values).flatten
        else
          value.flat_map(&:values).reduce do |first, val|
            # invalid_fields will not be uniquely identified with a key. So it should be array
            if val.key?(:invalid_fields)
              first[:invalid_fields] ||= []
              first[:invalid_fields] += val[:invalid_fields]
              first
            else
              first.deep_merge(val)
            end
          end
        end
      end

      def action_content(key, value)
        if PROPERTY_ACTIONS.include?(key)
          type = :property_update
          content = (send(key, value) if respond_to?(key.to_s, true))
        elsif key.to_s == SPECIAL_ACTION_IDENTIFIER && SPECIAL_ACTIONS.include?(value[:type].to_sym) && respond_to?(value[:type], true)
          type = value[:type]
          content = safe_send(value[:type], value)
        elsif CONTENT_LESS_TYPES.include?(key)
          # content will be empty for this types
          type = type_mapping(send(key, value))
        elsif respond_to?(key.to_s, true)
          type = type_mapping(key)
          content = safe_send(key, value)
        elsif custom_field?(key)
          type = :property_update
          content = custom_fields(key, value)
        else # Fallback, content will not be formatted in this case
          type = key
          content = value
        end
        [type, content]
      end

      def type_mapping(type)
        ACTION_TYPE_MAPPING.keys.include?(type) ? ACTION_TYPE_MAPPING[type] : type
      end

      def activity_content
        @activity_content ||= JSON.parse(record.content).deep_symbolize_keys
      end

      def activity_content_hash
        activity_content[:system_changes].present? ? system_changes(activity_content[:system_changes]) : activity_content
      end

      def system_changes(value)
        value.values.first
      end

      def performing_rule(value)
        @rule_id = value.keys.first.to_s.to_i
        @rule_type = value.values.first[:rule].first.to_i
        @rule_name = value.values.first[:rule].last
      end

      def rule_exists?
        @query_data_hash[:rules][@rule_id].present?
      end

      def round_robin?(content)
        content[:activity_type] && content[:activity_type][:type] == 'round_robin'
      end

      def custom_field?(field)
        name = @query_data_hash[:field_mapping].key(field.to_s)
        return true unless name.present?
        name.ends_with?("_#{Account.current.id}")
      end

      def get_user(user_id)
        user = @query_data_hash[:users][user_id]
        if user.blank?
          Rails.logger.info("ticket_activities_api ::: user is nil, user_id: #{user_id}, ticket_id: #{@ticket.display_id}, account_id: #{Account.current.id}")
          return
        else
          parent = user.parent_id.zero? ? nil : @query_data_hash[:users][user.parent_id]
          parent.nil? ? user : parent
        end
      end

      # Property Update actions
      [:subject, :description].each do |name|
        define_method name do |value|
          { name => '*' }
        end
      end

      [:responder_id, :internal_agent_id, :requester_id].each do |name|
        define_method name do |value|
          if value[1].blank?
            { name => nil }
          else
            user = get_user(value[1].to_i)
            return if user.blank?
            { name => value[1].to_i }
          end
        end
      end

      [:priority, :source].each do |name|
        define_method name do |value|
          { name => value[1].present? ? value[1].to_i : nil }
        end
      end

      def status(value)
        {
          status: value[0].to_i,
          status_label: @query_data_hash[:status_name][value[0].to_i] || value[1]
        }
      end

      def thank_you_note(value)
        {
          thank_you_note: value[0]
        }
      end

      def ticket_type(value)
        { ticket_type: value[1] }
      end

      def group_id(value)
        { group_name: value[1] }
      end

      def internal_group_id(value)
        { internal_group_name: value[1] }
      end

      def product_id(value)
        { product_name: value[1] }
      end

      def due_by(value)
        time = parse_activity_time(value[1].to_i, false)
        return if time.blank?
        { due_by: time }
      end

      def skill_name(value)
        value[1]
      end

      # custom checkboxes
      def checked(value)
        custom_checkbox(value, true)
      end

      def unchecked(value)
        custom_checkbox(value, false)
      end

      def custom_checkbox(value, flag)
        result = {}
        value.each do |v|
          name_mapping = @query_data_hash[:field_mapping].key(v.to_s)
          if name_mapping.present?
            field_name = TicketDecorator.display_name(name_mapping)
            (result[:custom_fields] ||= {})[field_name] = flag
          else
            (result[:invalid_fields] ||= []) << { field_name: v, value: flag }
          end
        end
        result
      end

      # custom fields
      def custom_fields(field_name, value)
        name_mapping = @query_data_hash[:field_mapping].key(field_name.to_s)
        if name_mapping.present?
          { custom_fields: { TicketDecorator.display_name(name_mapping) => value[1] } }
        else
          { invalid_fields: [{ field_name: field_name, value: value[1] }] }
        end
      end

      # Note action
      def note(value)
        note_id = value[:id].to_i
        note = @query_data_hash[:notes][note_id]
        if note.nil?
          Rails.logger.info("ticket_activities_api ::: note is nil, note_id: #{note_id}, ticket_id: #{@ticket.display_id}, account_id: #{Account.current.id}")
          return
        end
        ConversationDecorator.new(note, ticket: @ticket).to_hash
      end

      def add_note(value = true)
        {
          add_note: value
        }
      end

      def forward_ticket(value = true)
        {
          forward_ticket: value
        }
      end

      def delete_status(value)
        {
          deleted_value: value[0],
          current_value: value[1].to_i
        }
      end

      def delete_group(value)
        {
          deleted_value: value[0]
        }
      end

      def deleted(value)
        value[1] ? :delete : :restore
      end

      def spam(value)
        value[1] ? :spam : :unspam
      end

      def archive(_value)
        :archive
      end

      # Special Activities
      def ticket_merge_source(value)
        { target_ticket_id: value[:target_ticket_id][0].to_i }
      end

      def ticket_merge_target(value)
        { source_ticket_ids: value[:source_ticket_id].map(&:to_i) }
      end

      def ticket_split_source(value)
        { target_ticket_id: value[:target_ticket_id][0].to_i }
      end

      def ticket_split_target(value)
        { source_ticket_id: value[:source_ticket_id][0].to_i }
      end

      def ticket_import(value)
        # Time from activities service is not calculated with multiplier in this case
        imp_time = parse_activity_time(value[:imported_at].to_i, false)
        { imported_at: imp_time }
      end

      def round_robin(value)
        round_robin_hash = {}
        round_robin_hash[:skill_name] = skill_name(value[:skill_name]) if value[:skill_name].present?
        round_robin_hash.merge!(responder_id(value[:responder_id])) if value[:responder_id].present?
        round_robin_hash
      end

      # Tags & Rules Related activities

      [:add_tag, :remove_tag, :add_a_cc, :email_to_group, :tracker_link, :tracker_unlink, :assoc_parent_tkt_unlink].each do |name|
        define_method name do |values|
          values.compact.map do |value|
            value.to_i == 0 ? value : value.to_i
          end
        end
      end

      def email_to_requester(value)
        user = get_user(value[0].to_i)
        return if user.blank?
        value.map(&:to_i)
      end

      def email_to_agent(value)
        user_ids = value.select do |id|
          get_user(id.to_i).present?
        end
        return if user_ids.blank?
        user_ids.map(&:to_i)
      end

      # watchers
      def watcher(value)
        user_ids = []
        watcher_arr = value[:user_id]
        if watcher_arr[1].to_i.zero?
          flag = false
          user = get_user(watcher_arr[0].to_i)
        else
          flag = true
          user = get_user(watcher_arr[1].to_i)
        end
        user_ids << user.id if user.present?
        return if user_ids.blank?
        { add_watcher: flag, user_ids: user_ids }
      end

      def add_watcher(value)
        user_ids = value.select do |id|
          get_user(id.to_i).present?
        end
        return if user_ids.count.zero?
        {
          add_watcher: true,
          user_ids: user_ids.map(&:to_i)
        }
      end

      # scenario automation
      def execute_scenario(value)
        { name: value[1] }
      end

      # Initial version of timesheet activity would have key as timesheet_old
      # So, adding this for old data
      def timesheet_old(value)
        if value.key?(:timer_running)
          timer_running(value)
        else
          time_spent(value)
        end
      end

      def timesheet_create(value)
        build_timesheet_params(value, true)
      end

      def timesheet_edit(value)
        {
          old_values: build_timesheet_params(value, false),
          new_values: build_timesheet_params(value, true)
        }
      end

      def timesheet_delete(value)
        build_timesheet_params(value, false)
      end

      def timer_running(value)
        { timer_running: value[:timer_running][1] }
      end

      def time_spent(value)
        value
      end

      def build_timesheet_params(value, flag)
        index  = flag ? 1 : 0
        user   = get_user(value[:user_id][index].to_i)
        params = {}
        params[:billable]      = value[:billable][index]
        params[:user_id]       = user.present? ? value[:user_id][index].to_i : nil
        params[:executed_at]   = parse_activity_time(value[:executed_at][index].to_i, false)
        params[:time_spent]    = value[:time_spent][index].to_i
        params[:timer_running] = value[:timer_running][index] if value.key?(:timer_running)
        params
      end

      def remove_group(value)
        {
          group_name: value[0],
          status_name: value[1]
        }
      end

      def remove_agent(value)
        user = get_user(value[0].to_i)
        return if user.blank?
        {
          user_id: value[0].to_i,
          group_name: value[1]
        }
      end

      def remove_status(value)
        value[0]
      end

      def shared_ownership_reset(value)
        result_hash = {}
        result_hash = internal_group_id(value[:internal_group_id]) if value[:internal_group_id].present?
        if value[:internal_agent_id].present?
          internal_agent_id = internal_agent_id(value[:internal_agent_id])
          result_hash.merge!(internal_agent_id) unless internal_agent_id.nil?
        end
        result_hash
      end

      [:delete_agent, :delete_internal_agent, :rel_tkt_link, :rel_tkt_unlink, :assoc_parent_tkt_link, :child_tkt_link, :child_tkt_unlink].each do |name|
        define_method name do |value|
          value[0].to_i
        end
      end

      def delete_internal_group(value)
        value[0]
      end

      def tracker_unlink_all(value)
        value.to_i
      end

      def tracker_reset(_value)
        :tracker_reset
      end

      def assoc_parent_tkt_open(_value)
        :parent_ticket_reopened
      end
  end
end
