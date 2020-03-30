class SolutionDashboardValidation < FilterValidation
  attr_accessor :portal_id

  validates :portal_id, numericality: { only_integer: true, greater_than: 0 }
end
