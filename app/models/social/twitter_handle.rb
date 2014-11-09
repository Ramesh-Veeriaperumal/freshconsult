class Social::TwitterHandle < ActiveRecord::Base

  self.table_name =  "social_twitter_handles"
  self.primary_key = :id

  concerned_with :associations, :constants, :validations, :callbacks

  serialize  :search_keys, Array

  scope :active, :conditions => { :state => TWITTER_STATE_KEYS_BY_TOKEN[:active] }
  scope :disabled, :conditions => {:state => TWITTER_STATE_KEYS_BY_TOKEN[:disabled] }
  scope :reauth_required, :conditions => {:state => TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]}
  scope :capture_mentions, :conditions => {:capture_mention_as_ticket => true}

  def search_keys_to_s
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

  def update_ticket_rules(dm_group_id=nil, includes=[], mention_group_id = nil)
    streams = self.twitter_streams
    changes = previous_changes

    unless streams.empty?
      default_stream = self.default_stream
      unless changes[:capture_mention_as_ticket].nil?
        if changes[:capture_mention_as_ticket][0] and !changes[:capture_mention_as_ticket][1]
          default_stream.ticket_rules.first.destroy unless (default_stream.ticket_rules.empty?)
        else
          default_stream.populate_ticket_rule(mention_group_id, ["#{formatted_handle}"])
        end
      else
        default_stream.update_ticket_action_data(mention_group_id) unless default_stream.ticket_rules.empty?
      end

      dm_stream = self.dm_stream
      unless changes[:capture_dm_as_ticket].nil?
        if changes[:capture_dm_as_ticket][0] and !changes[:capture_dm_as_ticket][1]
          dm_stream.ticket_rules.first.destroy unless (dm_stream.ticket_rules.empty?)
          
        else
          dm_stream.populate_ticket_rule(dm_group_id, includes)
        end
      else
        dm_stream.update_ticket_action_data(dm_group_id) unless dm_stream.ticket_rules.empty?
      end
    end
  end

  def default_stream
    streams = self.twitter_streams
    streams.each do |stream|
      return stream if stream.data[:kind] == STREAM_TYPE[:default]
    end
    return nil
  end

  def dm_stream
    streams = self.twitter_streams
    streams.each do |stream|
      return stream if stream.data[:kind] == STREAM_TYPE[:dm]
    end
    return nil
  end

  def find_custom_stream(keyword)
    streams = self.twitter_streams
    streams.each do |stream|
      return stream if (stream.data[:kind] == STREAM_TYPE[:custom] && stream.includes.include?(keyword))
    end
    return nil
  end

end
