class Search::Tickets::Docs < Search::Filters::Docs
  attr_accessor :params, :negative_params, :options

  def initialize(values=[], negative_values=[], options = {})
    @params           = (values.presence || [])
    @negative_params  = (negative_values.presence || [])
    @options          = options
  end

  def host(request_type = "put")
    Account.current.features?(:countv2_reads) ? ::COUNT_V2_HOST : ::COUNT_HOST
  end

  def alias_name(request_type = "put")
  	 Account.current.features?(:countv2_reads) ? "es_count_#{Account.current.id}" : "es_filters_#{Account.current.id}"
  end
end