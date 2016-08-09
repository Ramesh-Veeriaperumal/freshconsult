namespace :seed_tickets do

  require 'faker'

  desc "Generate twitter tickets"
  task :twitter => :environment do |args|
    puts "Populating ticket conversations for Account ID : #{ENV["ACCOUNT_ID"]}, USER_ID : #{ENV["USER_ID"]}"
    account_id = ENV["ACCOUNT_ID"]
    user_id = ENV["USER_ID"]
    Sharding.select_shard_of(account_id) do 
      account = Account.find(account_id).make_current
      user = account.agents.find_by_user_id(user_id).user.make_current
      define_factories
      generate_twitter_ticket_converstaions
    end
  end

  desc "Generate fb tickets"
  task :fb => :environment do
  end

  def define_factories
    FactoryGirl.define do
      factory :twitter_handle, :class => Social::TwitterHandle do
        screen_name "TestingGnip"
        capture_dm_as_ticket true
        capture_mention_as_ticket false
        search_keys []
        twitter_user_id { (Time.now.utc.to_f*1000000).to_i }
      end
      
      factory :twitter_stream, :class => Social::TwitterStream do
        name "Custom Social Stream"
        type "Social::TwitterStream"
        includes ["Freshdesk"]
        excludes []
        data HashWithIndifferentAccess.new({:kind => "Custom" })
        filter HashWithIndifferentAccess.new({:exclude_twitter_handles => []})
      end
    end
  end

  def generate_twitter_ticket_converstaions(options = {})
    stream_id = get_twitter_stream_id(options)
    twitter_handle = get_twitter_handle(options)

    tickets_count = options[:count] || rand(2..5)
    tickets_count.times do

      tweet = new_tweet({ :stream_id => stream_id })
      requester = create_tweet_user(tweet[:user])
      ticket = create_twitter_ticket({
        :twitter_handle => twitter_handle,
        :tweet => tweet,
        :requester => requester  
      })

      notes_count = rand(2..7)
      notes_count.times do
        if ['agent', 'customer'].sample == 'agent'
          twitter_agent_reply_to_ticket(ticket, {
            :tweet => new_tweet({ :twitter_user => tweet[:user] })
              .merge({ :body => "@#{requester.twitter_id} #{Faker::Lorem.sentence}" }),
            :twitter_handle => twitter_handle,
            :stream_id => stream_id
          })
        else
          twitter_customer_reply_to_ticket(ticket, {
          :tweet => new_tweet({
            :twitter_user => tweet[:user]
          }),
          :twitter_handle => twitter_handle,
          :stream_id => stream_id
        })
        end
      end
    end
  end

  def get_twitter_stream_id(options = {})
    options[:stream_id] || Account.current.twitter_streams.sample.id && return
    stream  = FactoryGirl.build(:twitter_stream)
    stream.account_id = Account.current.id
    stream.save
    stream.id
  end

  def get_twitter_handle(options = {})
    (options[:twitter_handle] || Account.current.twitter_handles.sample) && return
    handle = FactoryGirl.build(:twitter_handle)
    handle.account_id = Account.current.id
    handle.save
    handle
  end

  def create_twitter_ticket(options = {})
    twitter_handle = options[:twitter_handle] || FactoryGirl.build(:twitter_handle)
    
    if twitter_handle.new_record?
      twitter_handle.account_id = Account.current.id
      twitter_handle.save
    end

    tweet = options[:tweet] || new_tweet(options[:stream_id])
    requester = options[:requester] || create_tweet_user(tweet[:user])

    twitter_ticket = Account.current.tickets.build(
      :subject    => Helpdesk::HTMLSanitizer.plain(tweet[:body]),
      :twitter_id => requester.twitter_id,
      :product_id => twitter_handle.product_id,
      :group_id   => options[:group_id] || ( twitter_handle.product ? twitter_handle.product.primary_email_config.group_id : nil),
      :source     => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
      :created_at =>  Time.at(Time.parse(tweet[:posted_time]).to_i),
      :tweet_attributes => {
        :tweet_id           => tweet[:id],
        :tweet_type         => tweet[:type],
        :twitter_handle_id  => twitter_handle.id,
        :stream_id          => tweet[:stream_id]
      },
      :ticket_body_attributes => {
        :description_html => tweet[:body]
      }
    )
    twitter_ticket.requester = requester
    twitter_ticket.save
    twitter_ticket
  end

  def twitter_customer_reply_to_ticket(ticket, options = {})
    options[:twitter_handle] ||= Account.current.twitter_handles.find_by_id(ticket.fetch_twitter_handle)
    options[:stream_id] ||= options[:twitter_handle].default_stream_id

    note_params = {
      :incoming   => true,
      :user_id    => ticket.requester.id 
    }.merge(note_common_params(options))
    note = ticket.notes.build(note_params)
    note.account_id = Account.current.id
    note.save
    note
  end

  def twitter_agent_reply_to_ticket(ticket, options = {})
    options[:twitter_handle] ||= Account.current.twitter_handles.find_by_id(ticket.fetch_twitter_handle)
    options[:stream_id] ||= options[:twitter_handle].default_stream_id

    note_params = {
      :private => false,
      :user_id => User.current.id
    }.merge(note_common_params(options))
    note = ticket.notes.build(note_params)
    note.account_id = Account.current.id
    note.save
    note
  end

  def note_common_params(options = {})
    {
      :note_body_attributes => {
        :body_html => options[:tweet][:body]
      },
      :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
      :created_at => Time.at(Time.parse(options[:tweet][:posted_time]).to_i),
      :tweet_attributes => {
        :tweet_id => options[:tweet][:id],
        :tweet_type => options[:tweet][:type],
        :twitter_handle_id => options[:twitter_handle].id,
        :stream_id => options[:stream_id]
       }
    }
  end

  def new_tweet(options = {})
    { 
      :stream_id => options[:stream_id],
      :feed_id => options[:feed_id] || Time.now.utc.to_f,
      :posted_time => Time.now.strftime("%FT%T.000Z"),
      :user => options[:twitter_user] || twitter_user,
      :source => 'Twitter',
      :in_reply_to => nil,
      :ticket_id => options[:ticket_id],
      :is_replied => nil,
      :user_in_db => false,
      :in_conv => false,
      :agent_name => options[:agent_name],
      :id => "#{Time.now.to_i}#{rand(0..5000)}",
      :type => options[:tweet_type] || ['dm', 'mention'].sample
    }.merge(mentions_and_body(options))
  end

  def mentions_and_body(options = {})
    mentions = Faker::Lorem.words(1)
    {
      :user_mentions => mentions,
      :body => "#{Faker::Lorem.sentence} #{mentions.map {|m| '@'+m}.join(' ')}"
    }
  end

  def twitter_user
    name = Faker::Name.name
    {
      :name => name,
      :screen_name => name.gsub(/\W+/, ''),
      :id => "#{Time.now.to_i}#{rand(0..5000)}", 
      :followers_count => rand(100..20000),
      :klout_score => 0
    }
  end

  def create_tweet_user(details)
    user = Account.current.users.build(
      :name => details[:name],
      :twitter_id => details[:screen_name]
    )
    user.save
    user
  end

end