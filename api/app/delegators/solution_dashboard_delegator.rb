class SolutionDashboardDelegator < BaseDelegator
  include SolutionConcern
  validate :validate_portal_id

  def initialize(_item, options = {})
    options.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
    super(options)
  end
end
