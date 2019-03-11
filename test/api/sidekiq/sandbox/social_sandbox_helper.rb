['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module SocialSandboxHelper
  ACTIONS = ['create'].freeze

  def create_twitter_handles_data(account)
    twitter_handle_data = []
    handle = FactoryGirl.build(:seed_twitter_handle)
    handle.account_id = account.id
    handle.save
    twitter_handle_data << handle.attributes.merge('model' => handle.class.name, 'action' => 'added')
    twitter_handle_data
  end

  def create_twitter_streams_data(account)
    twitter_stream_data = []
    handle = account.twitter_handles.first
    stream = nil
    if handle.present?
      stream = FactoryGirl.build(:seed_dm_twitter_stream)
      stream.account_id = account.id
      stream.social_id = handle.id
    else
      stream = FactoryGirl.build(:seed_twitter_stream)
      stream.account_id = account.id
    end
    stream.save
    twitter_stream_data << stream.attributes.merge('model' => stream.class.name, 'action' => 'added')
    twitter_stream_data
  end

  def create_social_ticket_rules_data(account)
    social_rules_data = []
    stream = account.twitter_streams.first
    rule = FactoryGirl.build(:seed_social_filter_rules)
    rule.account_id = account.id
    rule.stream_id = stream.id
    rule.save
    social_rules_data << rule.attributes.merge('model' => rule.class.name, 'action' => 'added')
    social_rules_data
  end
end
