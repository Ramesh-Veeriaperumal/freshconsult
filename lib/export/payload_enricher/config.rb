class Export::PayloadEnricher::Config
  attr_accessor :fields

  def initialize
    @fields = { :ticket => [], :user => [], :company => [] }
  end

  def add_fields(model_type, new_fields=[])
    @fields[model_type] |= new_fields if @fields[model_type]
  end

  def company_fields
    @fields[:company]
  end

  def ticket_fields
    @fields[:ticket]
  end

  def user_fields
    @fields[:user]
  end

end