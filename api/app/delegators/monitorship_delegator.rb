class MonitorshipDelegator < SimpleDelegator
  include ActiveModel::Validations

  validates :user, presence: true
end
