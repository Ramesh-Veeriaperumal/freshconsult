class AdvancedTicketingDelegator < BaseDelegator
  validate :feature_toggle_enabled?, on: :create
  validate :validate_feature_absence, on: :create
  validate :validate_feature_presence, on: :destroy

  def initialize(record, options = {})
    @item = record
    options.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
    super(record, options)
  end

  def feature_toggle_enabled?
    unless Account.current.safe_send("#{@feature}_toggle_enabled?")
      errors[:name] << :require_feature
      @error_options[:feature] = @feature
    end
  end

  def validate_feature_absence
    if Account.current.safe_send("#{@feature}_enabled?") || (@item && Account.current.installed_applications.find_by_application_id(@item.id))
      errors[:name] << :feature_exists
      @error_options[:feature] = @feature
    end
  end

  def validate_feature_presence
    unless Account.current.safe_send("#{@feature}_enabled?")
      errors[:id] << :feature_unavailable
      @error_options[:feature] = @feature
    end
  end

end