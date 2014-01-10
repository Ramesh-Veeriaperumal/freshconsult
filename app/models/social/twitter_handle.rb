class Social::TwitterHandle < ActiveRecord::Base

  set_table_name "social_twitter_handles"

  concerned_with :associations, :constants, :validations, :callbacks

  serialize  :search_keys, Array

  named_scope :active, :conditions => { :state => TWITTER_STATE_KEYS_BY_TOKEN[:active] }
  named_scope :disabled, :conditions => {:state => TWITTER_STATE_KEYS_BY_TOKEN[:disabled] }
  named_scope :reauth_required, :conditions => {:state => TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]}
  named_scope :capture_mentions, :conditions => {:capture_mention_as_ticket => true}

  def search_keys_string
    search_keys.blank? ? "" : search_keys.join(",")
  end

  def formatted_handle
    "@#{screen_name}"
  end

  def reauth_required?
    state == TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]
  end

  def check_ticket_rules # @ARV@ TODO REMOVE_AFTER_MIGRATION
    {:convert => capture_mention_as_ticket? }
  end
  
  def default_stream_id
    stream = self.default_stream
    stream_id = stream.id if stream
  end

  def default_stream
    streams = self.twitter_streams
    streams.each do |stream|
      return stream if stream.data[:kind] == STREAM_TYPE[:default]
    end
    return nil
  end

end
