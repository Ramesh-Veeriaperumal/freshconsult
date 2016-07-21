class Search::Tickets::Docs < Search::Filters::Docs
  attr_accessor :params, :negative_params, :options, :list_page

  def initialize(values=[], negative_values=[], options = {})
    @params           = (values.presence || [])
    @negative_params  = (negative_values.presence || [])
    @options          = options
    @list_page		    = !Account.current.launched?(:list_page_new_cluster)
  end

  def host(request_type = "put")
    Account.current.launched?(:list_page_new_cluster) ? ::COUNT_V2_HOST : ::COUNT_HOST
  end

  def alias_name(request_type = "put")
  	Account.current.launched?(:list_page_new_cluster) ? "es_count_#{Account.current.id}" : "es_filters_#{Account.current.id}"
  end
end