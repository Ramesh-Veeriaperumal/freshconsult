class Facebook::DataFetcher::MessageFetcher < Facebook::DataFetcher
  def initialize(thread, fan_page)
    @fan_page = fan_page
    @thread = thread
    @fb_data = thread['messages']
    super(fan_page)
  end

  def least_fetched_entry
    Time.parse(data.collect { |message| message['created_time'] }.compact.min).to_i
  end

  def messages
    reject_old_data('created_time')
    data
  end

  def fetch_next_page
    @fb_data = execute_api_call(@thread['id'], FB_API_MESSAGES, FB_DM_DEFAULT_API_OPTIONS.merge(after: after), FB_API_HTTP_COMPONENT.dup)
    reject_old_data('created_time')
    data
  end
end
