class Social::TwitterHandle < ActiveRecord::Base
  publishable on: [:create, :destroy]
  publishable on: :update, if: :changes_except_last_dm?
  self.table_name =  "social_twitter_handles"
  self.primary_key = :id

  concerned_with :associations, :constants, :validations, :callbacks, :presenter

  serialize  :search_keys, Array

  scope :active, :conditions => { :state => TWITTER_STATE_KEYS_BY_TOKEN[:active] }
  scope :disabled, :conditions => {:state => TWITTER_STATE_KEYS_BY_TOKEN[:disabled] }
  scope :reauth_required, :conditions => {:state => TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]}
  scope :capture_mentions, :conditions => {:capture_mention_as_ticket => true}
  
  scope :paid_acc_handles, 
              :conditions => ["subscriptions.state IN ('active', 'free')"],
              :joins      =>  "INNER JOIN `subscriptions` ON subscriptions.account_id = social_twitter_handles.account_id"
              
  scope :trail_acc_handles, 
              :conditions => ["subscriptions.state = 'trial'"],
              :joins      => "INNER JOIN `subscriptions` ON subscriptions.account_id = social_twitter_handles.account_id"

  def search_keys_to_s
    search_keys.blank? ? "" : search_keys.join(",")
  end

  def formatted_handle
    "@#{screen_name}"
  end

  def reauth_required?
    state == TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]
  end

  def activation_required?
    state == TWITTER_STATE_KEYS_BY_TOKEN[:activation_required]
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
        default_stream.update_ticket_action_data(self.product_id, mention_group_id) unless default_stream.ticket_rules.empty?
      end

      dm_stream = self.dm_stream
      unless changes[:capture_dm_as_ticket].nil?
        if changes[:capture_dm_as_ticket][0] and !changes[:capture_dm_as_ticket][1]
          dm_stream.ticket_rules.first.destroy unless (dm_stream.ticket_rules.empty?)
          
        else
          dm_stream.populate_ticket_rule(dm_group_id, includes)
        end
      else
        dm_stream.update_ticket_action_data(self.product_id, dm_group_id) unless dm_stream.ticket_rules.empty?
      end
    end
  end

  def default_stream
    self.twitter_streams.detect{|stream| stream.data[:kind] == TWITTER_STREAM_TYPE[:default]}
  end

  def dm_stream
    self.twitter_streams.detect{|stream| stream.data[:kind] == TWITTER_STREAM_TYPE[:dm]}
  end

  def find_custom_stream(keyword)
    streams = self.twitter_streams
    streams.each do |stream|
      return stream if (stream.data[:kind] == TWITTER_STREAM_TYPE[:custom] && stream.includes.include?(keyword))
    end
    return nil
  end

  def self.drop_advanced_twitter_data(account)
    account.twitter_handles.order("created_at asc").find_each do |twitter|
      if twitter.smart_filter_enabled
        twitter.smart_filter_enabled = 0 
        twitter.default_stream.prepare_for_downgrade_to_sprout
        twitter.save!
      end
    end
  end

  def activate_mention_streams
    stream = default_stream
    stream.data[:gnip] = true
    stream.data[:gnip_rule_state] = Social::Constants::GNIP_RULE_STATES_KEYS_BY_TOKEN[:none]
    if stream.save
      stream.subscribe_to_gnip
    else
      Rails.logger.error "Error while activating the stream :: #{stream.id} :: account id :: #{stream.account_id}"
      raise
    end
  end
  def changes_except_last_dm?
    changes = self.previous_changes || {}
    changes.except!('last_dm_id')
    changes.present?
  end

  def changes_except_last_dm?
    changes = self.previous_changes || {}
    changes.except!('last_dm_id')
    changes.present?
  end
end
