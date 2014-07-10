#require '../spec_helper'
require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module GnipHelper

  def sample_gnip_feed(rule_hash=nil, reply=nil, time = Time.now.utc.iso8601)
    tweet_id = (Time.now.utc.to_f*100000).to_i
    feed_hash = {
      "body" => "@TestingGnip #{Faker::Lorem.words(20).join(" ")}",
      "retweetCount" => 2,
      "gnip" => {
        "matching_rules" => [{
                "tag" =>"0_0",
                "value" => "@TestingGnip"
            }],
        "klout_score" => "0"
      },
      "actor" => {
        "preferredUsername" => "GnipTestUser",
        "image" => "https://si0.twimg.com/profile_images/2816192909/db88b820451fa8498e8f3cf406675e13_normal.png",
        "id" => "id:twitter.com:#{(Time.now.utc.to_f*100000).to_i}",
        "displayName" => "Gnip Test User"
      },
      "verb" => "post",
      "postedTime" => time,
      "id" => "tag:search.twitter.com,2005:#{tweet_id}"
    }

    unless rule_hash.nil?
      rule = {
        "value" => rule_hash[:rule_value],
        "tag" => rule_hash[:rule_tag]
      }
      feed_hash["gnip"]["matching_rules"] = [rule]
    end

    unless reply.nil?
      feed_hash["inReplyTo"] = {
        "link" => "http://twitter.com/FreshArvind/statuses/#{reply}"
      }
      feed_hash["body"] = "@TestingGnip #{Faker::Lorem.words(20).join(" ")}"
    end

    return feed_hash
  end

  def verify_mention_rule(stream,mention=nil)
    ticket_rule = stream.ticket_rules.first
    ticket_rule.should_not be_nil
    ticket_rule.filter_data[:includes].should be_empty
  end

  def gnip_rule(rule)
    powertrack_envs = ["production"]
    source = Gnip::Constants::SOURCE[:twitter]

    rule_value = rule[:value]
    rule_tag = rule[:tag]

    rule_value.should_not be_nil
    rule_tag.should_not be_nil

    powertrack_envs.each do |env|
      @url = GnipConfig::RULE_CLIENTS[source][env.to_sym]
      mrule = matching_gnip_rule(rule_value)
      return mrule
    end
  end

  private
    def equality?(*args)
      args.first.downcase.strip().eql?(args.second.downcase.strip())
    end

    def matching_gnip_rule(value)
      list = @url.list
      list.each do |rule|
        rule_val = rule.value
        return rule if equality?(rule_val, value)
      end
      return nil
    end

end
