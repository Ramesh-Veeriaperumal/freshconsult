class BotDelegator < BaseDelegator
  validate :can_create_bot?, if: :portal_id_dependant_actions
  validate :validate_attachment, if: :create_or_update?
  validate :validate_categories, on: :map_categories
  validate :validate_mock_data, on: :remove_analytics_mock_data

  NEW_AND_CREATE_ACTIONS = %i[new create].freeze

  def initialize(record, options = {})
    @item = record
    options.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
    super(record, options)
  end

  def can_create_bot?
    if !@portal
      errors[:portal_id] << :invalid_portal
    elsif @support_bot
      # Return bot_id if bot already present and eventually redirect to show page.
      errors[:bot_id] << "#{@support_bot.id}"
    end
  end

  def validate_attachment
    return if @avatar.nil? || @avatar['is_default'] ||
              (@avatar['is_default'].nil? && @support_bot && @support_bot.additional_settings[:is_default])
    errors[:avatar] << :invalid_attachment unless Account.current.attachments.where(id: @avatar['avatar_id']).first
  end

  def validate_categories
    errors[:category_ids] << :invalid_category_ids unless (@category_ids - portal.solution_category_metum_ids).empty?
  end

  def validate_mock_data
    errors[:id] << :not_mock_data unless @item.additional_settings[:analytics_mock_data]
  end

  private

    def portal_id_dependant_actions
      NEW_AND_CREATE_ACTIONS.include?(validation_context)
    end
end
