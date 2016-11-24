namespace :seed_tickets do
  require 'faker'
  require "#{Rails.root}/spec/helpers/social_tickets_helper.rb"
  include SocialTicketsHelper

  desc 'Generate twitter tickets'
  # usage rake seed_tickets:twitter[1,1]  first arg is account_id, second is user_id
  task :twitter, [:account_id, :user_id] => :environment do |t, args|
    seed_social_tickets(*account_user_ids(args, :twitter), [:twitter_conversations])
  end

  desc 'Generate facebook tickets'
  # usage rake seed_tickets:facebook[1,1]  first arg is account_id, second is user_id
  task :facebook, [:account_id, :user_id] => :environment do |t, args|
    seed_social_tickets(*account_user_ids(args, :facebook), [:fb_conversations])
  end

  task :social, [:account_id, :user_id] => :environment do |t, args|
    seed_social_tickets(*account_user_ids(args), [:fb_conversations, :twitter_conversations])
  end

  def account_user_ids(args, channel = :social)
    account_id = args[:account_id] || ENV['ACCOUNT_ID'] || Account.first.id
    user_id = args[:user_id] || ENV['USER_ID'] || Account.first.agents.first.user_id
    puts "Seeding #{channel} tickets for Account ID : #{account_id}, User ID : #{user_id}"
    [account_id, user_id]
  end

  def seed_social_tickets(account_id, user_id, methods)
    Sharding.select_shard_of(account_id) do
      account = Account.find(account_id).make_current
      account.agents.find_by_user_id(user_id).user.make_current
      define_social_factories
      (methods || []).each do |meth|
        send(meth)
      end
    end
  end
end
