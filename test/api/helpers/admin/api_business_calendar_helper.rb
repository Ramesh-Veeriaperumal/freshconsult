module Admin::ApiBusinessCalendarHelper
  DAYS = %w[sunday monday tuesday wednesday thursday friday saturday].freeze

  def ember_business_hours_create_pattern(business_hour, options = {})
    response = {
      name: options[:name] || business_hour.try(:name),
      description: options[:description] || business_hour.try(:description),
      default: options[:is_default] || business_hour.try(:is_default),
      time_zone: options[:time_zone] || business_hour.try(:time_zone),
      holidays: options[:holidays] || holiday_decorator(business_hour),
      channel_business_hours: options[:channel_business_hours] || business_hour.try(:channel_bussiness_hour_data)
    }
    response.merge!(id: business_hour.try(:id)) if business_hour.present?
    response
  end

  def omni_business_hours_show_pattern(business_hour, channel_hours)
    response = {
      name: business_hour.try(:name),
      description: business_hour.try(:description),
      default: business_hour.try(:is_default),
      time_zone: business_hour.try(:time_zone),
      holidays: holiday_decorator(business_hour) || options[:holidays],
      channel_business_hours: channel_hours
    }
    response.merge!(id: business_hour.try(:id)) if business_hour.present?
    response
  end

  def holiday_decorator(business_hour)
    return nil if business_hour.nil?

    business_hour.holiday_data.map { |data| { name: data[1], date: data[0] } }
  end

  def expected_create_response(params)
    params = params.deep_symbolize_keys
    expected_response_pattern = params
    expected_response_pattern[:channel_business_hours] = params[:channel_business_hours].reject { |channel_hash| ['chat', 'phone'].include?(channel_hash[:channel]) }
    expected_response_pattern[:channel_business_hours] = expected_response_pattern[:channel_business_hours] |
                                                         [
                                                           { channel: ApiBusinessCalendarConstants::CHAT_CHANNEL, sync_status: BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress] },
                                                           { channel: ApiBusinessCalendarConstants::PHONE_CHANNEL, sync_status: BusinessCalenderConstants::OMNI_SYNC_STATUS[:inprogress] }
                                                         ]
    expected_response_pattern
  end

  def dummy_business_calendar_default_params
    {
      name: 'Dark web with social engineering',
      description: 'useless',
      time_zone: 'Edinburgh'
    }
  end

  def dummy_holiday_data
    {
      "holidays": [
        {
          "date": 'Feb 29',
          "name": 'feb 31 holiday'
        },
        {
          "date": 'Apr 1',
          "name": 'april 30 holiday'
        }
      ]
    }
  end

  def dummy_channel_business_hours(channel = 'ticket', business_type = 'custom')
    [
      {
        'channel': channel,
        "business_hours_type": business_type.to_s
      }
    ]
  end

  def dummy_business_hours_data(day_to_use = 7, options = {})
    {
      "business_hours": randomized_list((0..6).to_a, 0, 6).slice(0, day_to_use).each_with_object([]) do |day_num, mapping|
        mapping << {
          "day": DAYS[day_num],
          "time_slots": options[:day_num] || [
            {
              "end_time": '23:59',
              "start_time": '00:00'
            }
          ]
        }
      end
    }
  end

  def randomized_list(list, from, to)
    (from..to).each do |index|
      next_ind = rand(to - index + 1) + from
      list[from], list[next_ind] = list[next_ind], list[from]
    end
    list
  end

  def ticket_business_hours_sample
    dummy_channel_business_hours.first.merge(dummy_business_hours_data(1))
  end

  def caller_channel_business_hours_sample
    @caller_channel_business_hours_sample ||= {
      channel_business_hours: [dummy_channel_business_hours('phone').first.merge(dummy_business_hours_data(1))]
    }
  end

  def chat_channel_business_hours_sample
    @chat_channel_business_hours_sample ||= {
      channel_business_hours: [dummy_channel_business_hours('chat').first
                                                                   .merge(dummy_business_hours_data(1))
                                                                   .merge("away_message": 'I am away')]
    }
  end

  def chat_channel_business_hours_away_message_sample
    @chat_channel_business_hours_away_message_sample ||= {
      channel_business_hours: [dummy_channel_business_hours('chat').first.merge(
        dummy_business_hours_data(1)
      ).merge("away_message": 'I am away')]
    }
  end

  def chat_channel_business_hours_breaks_sample
    @chat_channel_business_hours_breaks_sample ||= {
      channel_business_hours: [dummy_channel_business_hours('chat').first.merge(
        "business_hours": [{ "day": 'sunday', "time_slots": [{ "end_time": '10:30',
                                                               "start_time": '00:00' },
                                                             { "end_time": '11:30',
                                                               "start_time": '11:00' }] }]
      ).merge("away_message": 'I am away')]
    }
  end

  def fchat_account
    @fchat_account = Freshchat::Account.where(account_id: Account.current.id).first
    @fchat_account ||= create_freshchat_account Account.current
  end

  def chat_create_url
    'https://api.freshchat.com/v2/business_hours'
  end

  def chat_update_url(id)
    format("#{chat_create_url}/%{id}", id: id)
  end

  def stub_chat_bc_success(args)
    stub_request(:post, chat_create_url).to_return(body: (args[:chat] || {}).to_json, status: 201)
  end

  def stub_chat_business_calendar_update_success(id, args)
    stub_request(:put, chat_update_url(id)).to_return(body: (args[:chat] || {}).to_json, status: 200)
  end

  def stub_chat_create_failure
    stub_request(:post, chat_create_url).to_return(body: { "errors": ['Invalid data'] }.to_json,
                                                   status: 422,
                                                   headers: { 'Content-Type' => 'application/json' })
  end

  def stub_chat_business_calendar_update_failure(id)
    stub_request(:post, chat_update_url(id)).to_return(body: { "errors": ['Invalid data'] }.to_json,
                                                       status: 422,
                                                       headers: { 'Content-Type' => 'application/json' })
  end

  def show_chat_business_hours_sample(id)
    {
      id: id,
      name: 'chat calendar sample',
      description: 'string',
      time_zone: 'American Samoa',
      default: true,
      holidays: [
        { name: 'hol 1', date: 'aug 15' },
        { name: 'hol 2', date: 'may 01' },
        { name: 'hol 3', date: 'jun 06' }
      ],
      channel_business_hours: chat_channel_business_hours_sample[:channel_business_hours]
    }
  end
end
