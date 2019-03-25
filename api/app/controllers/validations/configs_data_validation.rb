class ConfigsDataValidation < ApiValidation
  attr_accessor :id
  validates :id, custom_inclusion: { in: ConfigsConstants::ALLOWED_IDS }
end
