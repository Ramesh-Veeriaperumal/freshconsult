# frozen_string_literal: true

module Channel::V2
  class SubscriptionValidation < AdminSubscriptionValidation
    include ChannelAuthentication

    validate :validate_add_addons, on: :update
    validate :validate_remove_addons, on: :update
    validate :validate_addon_params, on: :update
    validate :addon_applicability, on: :update

    def initialize(request_params, item, allow_string_param = false)
      @request_params = request_params
      super(request_params, item, allow_string_param)
      @account = Account.current
      @subscription = @account.subscription
    end

    def validate_add_addons
      return if errors[:addon].present?

      addons_to_add = @request_params['addons']['add']
      return if addons_to_add.empty?

      addons_to_add.each do |addon|
        errors.add(:addon, format(ErrorConstants::ERROR_MESSAGES[:duplicate_addon], addon: addon[:name])) if @subscription.addons.map(&:name).include?(addon[:name])
      end
      return false if errors[:addon].present?

      true
    end

    def validate_remove_addons
      return if errors[:addon].present?

      addons_to_remove = @request_params['addons']['remove']
      return if addons_to_remove.empty?

      addons_to_remove.each do |addon|
        errors.add(:addon, format(ErrorConstants::ERROR_MESSAGES[:missing_addon], addon: addon[:name])) unless @subscription.addons.map(&:name).include?(addon[:name])
      end
      return false if errors[:addon].present?

      true
    end

    def validate_addon_params
      return if errors[:addon].present?

      addons_to_add = @request_params['addons']['add']
      return if addons_to_add.empty?

      addons_to_add.each do |addon|
        errors.add(:addon, format(ErrorConstants::ERROR_MESSAGES[:invalid_addon], addon: addon[:name])) unless AddonConfig.keys.include?(addon[:name])
      end
      return false if errors[:addon].present?

      true
    end

    def addon_applicability
      return if errors[:addon].present?

      addons_to_add = @request_params['addons']['add']
      return if addons_to_add.empty?

      plan = fetch_plan
      addons_to_add.each do |addon|
        errors.add(:addon, format(ErrorConstants::ERROR_MESSAGES[:addon_not_applicable], addon: addon[:name], plan: plan.name)) unless plan.addons.map(&:name).include?(addon[:name])
      end                                 
      return false if errors[:addon].present?

      true
    end

    private

      def fetch_plan
        if @request_params[:plan_id].present? && @request_params[:plan_id] != @subscription.plan_id
          plan = SubscriptionPlan.current.find_by_id(params[:plan_id])
        else
          plan = @account.subscription.subscription_plan
        end
        plan
      end
  end
end
