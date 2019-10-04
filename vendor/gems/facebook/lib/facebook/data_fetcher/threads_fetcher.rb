class Facebook::DataFetcher::ThreadsFetcher < Facebook::DataFetcher
  def initialize(fan_page)
    @fan_page = fan_page
    super
  end

  def least_fetched_entry
    Time.parse(data.collect { |thread| thread['updated_time'] }.compact.min).to_i
  end

  def fetch_threads(options = FB_THREAD_DEFAULT_API_OPTIONS)
    @fb_data = execute_api_call(FB_API_ME, FB_API_CONVERSATIONS, options, FB_API_HTTP_COMPONENT.dup)
    process_threads
  end

  def process_threads
    reject_old_data('updated_time')
    data.each do |thread|
      # To avoid missing out older messages, we loop and hit the API until we receive an older value
      fb_message_fetcher = Facebook::DataFetcher::MessageFetcher.new(thread, @fan_page)
      thread['messages']['data'] = fb_message_fetcher.messages
      while fb_message_fetcher.next_page?
        thread['messages']['data'] += fb_message_fetcher.fetch_next_page
      end
    end
    data.reject! { |thread| thread['messages']['data'].empty? }
    data
  end

  def fetch_next_page
    fetch_threads(FB_THREAD_DEFAULT_API_OPTIONS.merge(after: after))
  end
end
