module SocialTicketsHelper
  def define_social_factories
    FactoryGirl.define do
      factory :seed_twitter_handle, class: Social::TwitterHandle do
        screen_name 'TestingGnip'
        capture_dm_as_ticket true
        capture_mention_as_ticket false
        smart_filter_enabled true
        search_keys []
        twitter_user_id { (Time.now.utc.to_f * 1_000_000).to_i }
      end

      factory :seed_twitter_stream, class: Social::TwitterStream do
        name 'Custom Social Stream'
        type 'Social::TwitterStream'
        includes ['Freshdesk']
        excludes []
        data HashWithIndifferentAccess.new(kind: 'Custom')
        filter HashWithIndifferentAccess.new(exclude_twitter_handles: [])
      end

      factory :seed_facebook_pages, class: Social::FacebookPage do
        sequence(:page_id) { |n| n }
        profile_id (Time.now.to_f * 10**6).to_i
        page_token Digest::SHA256.new.update(Time.zone.now.to_s).hexdigest
        page_name Faker::Lorem.sentence
        access_token Digest::SHA256.new.update(Time.zone.now.to_s).hexdigest
        enable_page true
        fetch_since 0
        import_visitor_posts false
        import_company_posts false
        realtime_subscription true
      end
    end
  end

  def twitter_conversations(options = {})
    stream_id = get_twitter_stream_id(options)
    twitter_handle = get_twitter_handle(options)

    tickets_count = options[:count] || rand(2..5)
    tickets_count.times do
      tweet = new_tweet(stream_id: stream_id)
      requester = create_tweet_user(tweet[:user])
      ticket = create_twitter_ticket(
        twitter_handle: twitter_handle,
        tweet: tweet,
        requester: requester
      )

      notes_count = rand(2..7)
      notes_count.times do
        note_options = {
          tweet: new_tweet(twitter_user: tweet[:user]),
          twitter_handle: twitter_handle,
          stream_id: stream_id
        }
        is_agent_reply = %w(agent customer).sample == 'agent'
        if is_agent_reply
          note_options[:tweet][:body] = "@#{requester.twitter_id} #{Faker::Lorem.sentence}"
        end
        twitter_reply_to_ticket(ticket, note_options, is_agent_reply)
      end
    end
  end

  def get_twitter_stream_id(options = {})
    stream_id = options[:stream_id] || Account.current.twitter_streams.sample.try(:id)
    return stream_id if stream_id.present?
    stream = FactoryGirl.build(:seed_twitter_stream)
    stream.account_id = Account.current.id
    stream.save
    stream.id
  end

  def get_twitter_handle(options = {})
    handle = (options[:twitter_handle] || Account.current.twitter_handles.sample)
    return handle if handle.present?
    handle = FactoryGirl.build(:seed_twitter_handle)
    handle.account_id = Account.current.id
    handle.save
    handle
  end

  def create_twitter_ticket(options = {})
    tweet = options[:tweet] || new_tweet(options[:stream_id])
    requester = options[:requester] || create_tweet_user(tweet[:user])

    twitter_ticket = Account.current.tickets.build(
      subject:    Helpdesk::HTMLSanitizer.plain(tweet[:body]),
      twitter_id: requester.twitter_id,
      product_id: options[:twitter_handle].product_id,
      group_id:   options[:group_id] || (options[:twitter_handle].product ? options[:twitter_handle].product.primary_email_config.group_id : nil),
      source:     Helpdesk::Source::TWITTER,
      created_at: Time.zone.now, # Time.at(Time.parse(tweet[:posted_time]).to_i),
      tweet_attributes: tweet_attributes_params(options),
      ticket_body_attributes: {
        description_html: tweet[:body]
      }
    )
    twitter_ticket.requester = requester
    twitter_ticket.save
    twitter_ticket
  end

  def twitter_reply_to_ticket(ticket, options = {}, agent = false)
    options[:twitter_handle] ||= Account.current.twitter_handles.find_by_id(ticket.fetch_twitter_handle)
    options[:stream_id] ||= options[:twitter_handle].default_stream_id
    if agent
      note_params = { private: false, user_id: User.current.id }
    else
      note_params = { incoming: true, user_id:  ticket.requester.id }
    end
    note = ticket.notes.build(note_params.merge(note_common_params(options)))
    note.account_id = Account.current.id
    note.save
    note
  end

  def note_common_params(options = {})
    {
      note_body_attributes: {
        body_html: options[:tweet][:body]
      },
      source: Helpdesk::Source::TWITTER,
      created_at: Time.zone.now, # Time.at(Time.parse(options[:tweet][:posted_time]).to_i),
      tweet_attributes: tweet_attributes_params(options)
    }
  end

  def tweet_attributes_params(options = {})
    {
      tweet_id:          options[:tweet][:id],
      tweet_type:        options[:tweet][:type],
      twitter_handle_id: options[:twitter_handle].id,
      stream_id:         options[:stream_id]
    }
  end

  def new_tweet(options = {})
    {
      id:           (Time.zone.now.to_f * 10**6).to_i.to_s,
      stream_id:    options[:stream_id],
      feed_id:      options[:feed_id] || Time.zone.now.utc.to_f,
      type:         options[:tweet_type] || %w(dm mention).sample,
      posted_time:  Time.zone.now.strftime('%FT%T.000Z'),
      user:         options[:twitter_user] || twitter_user,
      source:       'Twitter',
      in_reply_to:  nil,
      ticket_id:    options[:ticket_id],
      is_replied:   nil,
      user_in_db:   false,
      in_conv:      false,
      agent_name:   options[:agent_name]
    }.merge(mentions_and_body)
  end

  def mentions_and_body
    mentions = Faker::Lorem.words(1)
    {
      user_mentions: mentions,
      body: "#{Faker::Lorem.sentence} #{mentions.map { |m| '@' + m }.join(' ')}"
    }
  end

  def twitter_user
    name = Faker::Name.name
    {
      id:               (Time.now.to_f * 10**6).to_i.to_s,
      name:             name,
      screen_name:      name.gsub(/\W+/, ''),
      followers_count:  rand(100..1000)
    }
  end

  def create_tweet_user(details)
    user = Account.current.users.build(
      name:       details[:name],
      twitter_id: details[:screen_name]
    )
    user.save
    user
  end

  # for facebook related ticket actions
  def fb_conversations(options = {})
    options[:fb_page] ||= Account.current.facebook_pages.first || create_fb_page(true)

    tickets_count = rand(2..5)
    tickets_count.times do
      options[:post] = fb_post_params
      ticket = create_fb_ticket(options)

      notes_count = rand(2..7)
      notes_count.times do
        options[:post] = fb_post_params
        fb_reply_to_ticket(ticket, options, [true, false].sample)
      end
    end
  end

  def create_fb_page(populate_streams = false)
    fb_page = FactoryGirl.build(:seed_facebook_pages, account_id: Account.current.id)
    fb_page.save
    fb_page.build_default_streams if populate_streams
    fb_page
  end

  def create_fb_ticket(options = {})
    requester = create_fb_user(options[:post][:from])
    fb_ticket = Account.current.tickets.build(
      subject:    "FB - #{options[:post][:message].truncate(100)}",
      requester:  requester,
      product_id: options[:fb_page].product_id,
      group_id:   options[:group_id],
      source:     Helpdesk::Source::FACEBOOK,
      created_at: Time.zone.now, # Time.zone.parse(options[:post][:created_time]),
      fb_post_attributes: get_fb_post_attributes(options),
      ticket_body_attributes: {
        description_html: options[:post][:message]
      }
    )
    fb_ticket.account_id = Account.current.id
    fb_ticket.save
    fb_ticket
  end

  def fb_reply_to_ticket(ticket, options = {}, agent = false)
    if agent
      note_params = {
        private: false,
        user_id: User.current.id
      }
    else
      note_params = {
        incoming: true,
        user_id: ticket.requester.id
      }
    end
    note = ticket.notes.build(note_params.merge(fb_note_common_params(options)))
    note.account_id = Account.current.id
    note.save
    note
  end

  def fb_note_common_params(options = {})
    {
      note_body_attributes: {
        body_html: options[:post][:message]
      },
      source:              Account.current.helpdesk_sources.note_source_keys_by_token['facebook'],
      created_at:          Time.zone.now, # Time.at(Time.parse(options[:tweet][:posted_time]).to_i),
      fb_post_attributes:  get_fb_post_attributes(options)
    }
  end

  def fb_post_params(options = {})
    {
      id:           (Time.now.to_f * 10**6).to_i,
      message:      Faker::Lorem.sentence(10),
      created_time: Time.now.utc.to_s,
      msg_type:     %w(post dm).sample, # msg type can either be a direct message (dm) or a post
      from:         options[:fb_user] || fb_user_params
    }
  end

  def fb_user_params
    {
      id:   Time.now.to_i.to_s,
      name: Faker::Name.name
    }
  end

  def create_fb_user(details)
    user = Account.current.users.build(
      name:           details[:name],
      fb_profile_id:  details[:id],
      helpdesk_agent: false
    )
    user.save
    user
  end

  def get_fb_post_attributes(options = {})
    # msg type can either be a direct message ('dm') or a post
    msg_type = options[:post][:msg_type] || %w(post dm).sample

    post_attrs = {}
    if msg_type != 'dm'
      post_type = Facebook::Constants::POST_TYPE_CODE.keys.sample
      post_type_code = options[:post_type_code] || Facebook::Constants::POST_TYPE_CODE[post_type]
      post_attrs = {
        post_attributes: {
          can_comment:  (post_type == :reply_to_comment ? false : true),
          post_type:    post_type_code
        }
      }
    end
    {
      post_id:          options[:post][:id],
      facebook_page_id: options[:fb_page].id,
      msg_type:         msg_type,
      thread_id:        options[:thread_id],
      parent_id:        options[:post][:parent_id]
    }.merge(post_attrs)
  end
end
