class Facebook::DataFetcher
  include Facebook::Constants

  def initialize(fan_page)
    @rest = Koala::Facebook::API.new(fan_page.page_token)
    @page_limit = DEFAULT_PAGE_LIMIT
  end

  def data
    @fb_data['data']
  end

  def paging
    @fb_data['paging']
  end

  def next_page
    paging['next']
  end

  def after
    paging['cursors']['after']
  end

  def messages_fetched_since
    Rails.logger.info("Messages fetched since for page #{@fan_page.id} is #{@fan_page.message_since}")
    @fan_page.message_since
  end

  def reject_old_data(identifier)
    data.reject! { |message| Time.parse(message[identifier]).to_i <= messages_fetched_since }
  end

  def execute_api_call(id, connection_name, options, additional_params = {})
    JSON.parse(@rest.get_connections(id, connection_name, options, additional_params))
  end

  def next_page?
    return false if @page_limit <= 0 || data.empty? || least_fetched_entry <= messages_fetched_since || next_page.nil? || after.nil? || data.length < DEFAULT_MESSAGE_LIMIT

    # Restricting the next page fetch logic to only 3 pages
    @page_limit -= 1
    true
  end
end
