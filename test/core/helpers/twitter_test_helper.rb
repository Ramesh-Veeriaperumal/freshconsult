module TwitterTestHelper
  def create_test_twitter_handle(account)
    handle = FactoryGirl.build(:twitter_handle, account_id: account.id)
    handle.capture_mention_as_ticket = 1
    handle.save!
    handle.reload
    handle
  end

  def cleanup_twitter_handles(account)
    account.twitter_handles.destroy_all
    account.tickets.where(source: 5).destroy_all
  end

  def stub_twitter_attachments_hash(media_url)
    { photo: { 'https://pbs.twimg.com/media/HsEgj7f3jhgWDR.jpg' => 'https://attachmenttestlink.com' }, twitter_url: media_url }
  end

  def sample_gnip_feed(account, stream, reply = false, media_url = nil, time = Time.now.utc.iso8601)
    tweet_id = (Time.now.utc.to_f * 1_000_000).to_i
    feed_hash = {
      'body' => "@TestingGnip #{Faker::Lorem.words(20).join(' ')}",
      'retweetCount' => 2,
      'gnip' => {
        'matching_rules' => [{
          'tag' => "S#{stream.id}_#{account.id}",
          'value' => '@TestingGnip'
        }],
        'klout_score' => '0'
      },
      'actor' => {
        'preferredUsername' => 'GnipTestUser',
        'image' => 'https://si0.twimg.com/profile_images/123134/db88b820451fa8498e8f3cf406675e13_normal.png',
        'id' => "id:twitter.com:#{tweet_id}",
        'displayName' => 'Gnip Test User'
      },
      'verb' => 'post',
      'postedTime' => time,
      'id' => "tag:search.twitter.com,2005:#{tweet_id}"
    }

    if reply
      feed_hash['inReplyTo'] = {
        'link' => "http://twitter.com/TestingGnip/statuses/#{reply}"
      }
    end

    unless media_url.nil?
      feed_hash['body'] = feed_hash['body'] + " #{media_url}"
      feed_hash['twitter_extended_entities'] = {
        'media' => [
          {
            'id' => 1_018_440_700_340_211_700,
            'id_str' => '1018440700340211712',
            'media_url' => 'http://pbs.twimg.com/media/HsEgj7f3jhgWDR.jpg',
            'media_url_https' => 'https://pbs.twimg.com/media/HsEgj7f3jhgWDR.jpg',
            'url' => media_url,
            'display_url' => 'pic.twitter.com/testingurl',
            'expanded_url' => "https://twitter.com/TestingGnip/status/#{tweet_id}/photo/1",
            'type' => 'photo'
          }
        ]
      }
    end
    feed_hash
  end
end
