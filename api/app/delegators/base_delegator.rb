class BaseDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options

  def initialize(record)
    super(record)
    @error_options = {}
  end
end
