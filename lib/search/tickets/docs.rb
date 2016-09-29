class Search::Tickets::Docs < Search::Filters::Docs
  attr_accessor :params, :negative_params, :options

  def initialize(values=[], negative_values=[], options = {})
    @params           = (values.presence || [])
    @negative_params  = (negative_values.presence || [])
    @options          = options
  end

  
end