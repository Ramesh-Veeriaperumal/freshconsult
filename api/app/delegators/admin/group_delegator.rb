# frozen_string_literal: true

module Admin
  class GroupDelegator < ::GroupDelegator
    validate :validate_agent_ids, if: -> { @agent_ids.present? }
    validate :validate_name, if: -> { @name.present? }

    def initialize(item, options = {})
      @agent_ids = options[:agent_ids]
      @name = options[:name]
      @item = item
      super(item, options)
    end

    private

      def validate_name
        # For validations using cache to reduce DB queries
        group = Account.current.groups_from_cache.find { |gr| gr.name == @name }
        if group.present? && (validation_context == :create || (validation_context == :update && @item.id != group.id))
          errors[:name] << :duplicate_group_name
          (error_options[:name] ||= {}).merge!(name: name)
        end
      end

      def validate_agent_ids
        invalid_users = invalid_users(@agent_ids)
        if invalid_users.present?
          errors[:agent_ids] << :invalid_list
          @error_options = { agent_ids: { list: invalid_users.join(', ').to_s } }
        end
      end

      def invalid_users(agent_list)
        (agent_list - Account.current.agents_details_from_cache.map(&:id))
      end
  end
end
