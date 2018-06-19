class PortalDelegator < BaseDelegator
  validate :can_create_bot?, on: :bot_prerequisites

  def initialize(record, options = {})
    options.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
    super(record, options)
    @portal = record
  end

  def can_create_bot?
    errors[:id] << :bot_exists if @portal.bot.present?
  end
end
