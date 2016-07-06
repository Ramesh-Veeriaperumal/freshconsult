class SurveyFilterValidation < FilterValidation
  attr_accessor :state

  validates :state, custom_inclusion: { in: SurveyConstants::STATES }

end
