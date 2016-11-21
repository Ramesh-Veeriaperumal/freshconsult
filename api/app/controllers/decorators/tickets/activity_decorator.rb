module Tickets
  class ActivityDecorator < ApiDecorator
    include ActivityConstants

    delegate :published_time, :actor, :event_type, to: :record
    
    SUPPORTED_ACTIVITIES = %w(responder_id note priority source status due_by).freeze
    LABEL_ONLY_ACTIVITIES = %w(execute_scenario product_id group_id).freeze
    TEXT_ONLY_FIELDS = %w(ticket_type).freeze
    NO_DECORATING_FOR = %w(add_tag remove_tag).freeze
    
    def initialize(record, options)
      super(record)
      @additional_info = options[:additional_info]
    end

    def to_hash
      {
        id: published_time, #Just for the sake of giving an id
        performer: performer_hash,
        performed_at: Time.at(published_time/10000), #10000 is to remove the precision introduced by the Activities service
        actions: send("#{performer_type}_actions")
      }
    end
    
    private

      def performer_hash
        {
          type: performer_type,
          "#{(performer_type == 'user' ? performer_type : 'rule')}" => send("performing_#{performer_type}")
        }
      end
      
      def user_actions
        action_array
      end
      
      def system_actions
        action_array(content['system_changes'][performing_rule_id.to_s].reject {|k| k.to_sym == :rule })
      end
      
      def action_array(items = content)
        # Rails.logger.debug "- " * 100
        Rails.logger.debug @additional_info[:field_mapping].values.inspect
        Rails.logger.debug "- " * 100
        
        (items.collect do |key, value|
          Rails.logger.debug ''
          Rails.logger.debug "Key: #{key}"
          Rails.logger.debug "Other Property? : #{@additional_info[:field_mapping].values.include?(key)}"
          if SUPPORTED_ACTIVITIES.include?(key)
            send("#{key}_activity", value)
          elsif @additional_info[:field_mapping].values.include?(key)
            other_property_activity(key, value)
          elsif NO_DECORATING_FOR.include?(key)
            {
              name: key,
              value: value
            }
          elsif TEXT_ONLY_FIELDS.include?(key)
            {
              name: key,
              value: value.last,
              label: value.last
            }
          elsif LABEL_ONLY_ACTIVITIES.include?(key)
            label_only_activity(key, value)
          else #Fallback
            {
              name: key,
              value: value
            }
          end
        end).collect do |item|
          Rails.logger.debug "*" * 100
          Rails.logger.debug item.inspect
          Rails.logger.debug (@additional_info[:field_mapping].values.include?(item[:name].to_s.downcase)).inspect
          Rails.logger.debug "*" * 100
          item[:type] ||= action_type(item[:name])
          item
        end
      end
      
      def action_type(item_name)
        @additional_info[:field_mapping].values.include?(item_name.to_s.downcase) ?
          :property : :action
      end

      def performer_type
        event_type.to_sym
      end

      def performing_user
        user = @additional_info[:users][actor]
        {
          id: user.id,
          name: user.name,
          avatar_url: user.avatar.try(:attachment_url_for_api, [true, :thumb]),
          agent: user.agent?
        }.merge(
          User.current.privilege?(:view_contacts) ? { email: user.email } : {})
      end

      def performing_system
        {
          id: performing_rule_id,
          type: RULE_LIST[content["system_changes"][performing_rule_id.to_s]["rule"].first.to_i],
          name: @additional_info[:rules][performing_rule_id]
        }
      end
      
      def content
        @content ||= JSON.parse(record.content)
      end
      
      def performing_rule_id
        (@additional_info[:rules].keys.collect(&:to_s) & content["system_changes"].keys).first.to_i
      end
      
      def responder_id_activity(value)
        
        {
          name: :responder_id,
          value: value.last.to_i,
          type: :property,
          label: @additional_info[:users][value.last.to_i].name
        }
      end
      
      def note_activity(value)
        {
          name: :note,
          type: :action,
          value: NoteDecorator.new(@additional_info[:notes][value['id'].to_i]).to_hash
        }
      end
      
      def priority_activity(value)
        {
          name: :priority,
          type: :property,
          value: value.last.to_i,
          label: TicketConstants::PRIORITY_NAMES_BY_KEY[value.last.to_i]
        }
      end

      def source_activity(value)
        {
          name: :source,
          type: :property,
          value: value.last.to_i,
          label: TicketConstants::SOURCE_TOKEN_BY_KEY[value.last.to_i]
        }
      end

      def status_activity(value)
        {
          name: :status,
          type: :property,
          value: value.first.to_i,
          label: @additional_info[:status_name][value.first.to_i] || value.last
        }
      end
      
      def label_only_activity(key, value)
        {
          name: key,
          type: :property,
          label: value.last
        }
      end
      
      def other_property_activity(key, value)
        {
          name: key,
          type: :property,
          value: value.last,
          label: value.last
        }
      end
      
      def due_by_activity(value)
        {
          name: :due_by,
          type: :property,
          value: Time.at(value.last.to_i).try(:utc)
        }
      end
    
  end
end