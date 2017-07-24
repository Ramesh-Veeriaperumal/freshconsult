class QuestFilterValidation < FilterValidation
  attr_accessor :filter
  validates :filter, custom_inclusion: { in: QuestConstants::FILTERS }
end
