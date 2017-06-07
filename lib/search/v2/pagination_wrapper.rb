class Search::V2::PaginationWrapper < Array

  MAX_PER_PAGE = 30

  attr_accessor :total, :options, :records

  def initialize(result_set, es_options={})
    @total    = es_options[:total_entries]
    @options  = {
      :page   => es_options[:page] || 1,
      :from   => es_options[:from] || 0
    }
    super(result_set)
  end

  #=> Will Paginate Support(taken from Tire) <=#
  def total_entries
    @total
  end

  def per_page
    MAX_PER_PAGE
  end

  def total_pages
    ( @total.to_f / per_page ).ceil
  end

  def current_page
    if @options[:page]
      @options[:page].to_i
    else
      (per_page + @options[:from].to_i) / per_page
    end
  end

  def previous_page
    current_page > 1 ? (current_page - 1) : nil
  end

  def next_page
    current_page < total_pages ? (current_page + 1) : nil
  end

  def offset
    per_page * (current_page - 1)
  end

  def out_of_bounds?
    current_page > total_pages
  end
end