class PortalDelegator < BaseDelegator
  attr_accessor :draft_logo
  validate :validate_draft_logo, if: -> { @id }
  validate :can_create_bot?, on: :bot_prerequisites

  def initialize(record, options = {})
    @id = options[:id]
    retrieve_helpdesk_logo(options) if @id
    options.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
    super(record, options)
    @portal = record
  end

  def validate_draft_logo
    return if @draft_logo.nil?
    errors[:draft_logo] << :invalid_attachment unless Account.current.attachments.where(id: @draft_logo['id']).first
  end

  private

    def retrieve_helpdesk_logo(_options)
      @draft_logo = Account.current.attachments.find(@id)
    end

    def can_create_bot?
      errors[:id] << :bot_exists if @portal.bot.present?
    end
end
