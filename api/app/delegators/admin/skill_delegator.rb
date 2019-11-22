module Admin
  class SkillDelegator < BaseDelegator
    include Admin::SkillConstants

    attr_accessor(*REQUEST_PERMITTED_PARAMS)

    validate :validate_name, if: -> { @request_params[:name].present? }
    validate :validate_filter_data, if: -> { @conditions.present? }


    def initialize(item, params, action)
      @request_params = params
      @action_name = action
      @conditions = @request_params[:conditions]
      @item = item
      DELEGATOR_FIELDS.each { |field| instance_variable_set("@#{field}", item[field]) }
      super(item)
    end

    private

      def validate_name
        duplicate_skill_name_error(@name) if Account.current.skills_from_cache.map(&:name).include?(@name)
      end

      def validate_filter_data
        conditions_delegator = conditions_delegator_class.new(@item, @conditions)
        if conditions_delegator.invalid?
          errors.messages.merge!(conditions_delegator.errors.messages)
          error_options.merge!(conditions_delegator.error_options)
        end
      end

      def conditions_delegator_class
        'ConditionsDelegator'.constantize
      end

      def duplicate_skill_name_error(skill_name)
        errors[:name] << :duplicate_skill_name
        (error_options[:name] ||= {}).merge!(name: skill_name)
      end
  end
end