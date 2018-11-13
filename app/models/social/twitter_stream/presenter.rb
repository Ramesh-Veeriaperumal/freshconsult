class Social::TwitterStream < Social::Stream
  include RepresentationHelper
  acts_as_api
  api_accessible :central_publish do |t|
    t.add :account_id
    t.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    t.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
    t.add proc { |x| x.data[:kind] }, as: :type
    t.add :rules
    t.add :id

  end

  api_accessible :central_publish_associations do |t|
    t.add :twitter_handle, template: :central_publish
  end

  def self.central_publish_enabled?
    Account.current.twitter_handle_publisher_enabled?
  end

  def relationship_with_account
    'twitter_streams'
  end

  def send_rule_condition?
    keyword_rules.present? && keyword_rules.first.action_data[:capture_dm_as_ticket]
  end

  def rules
    if send_rule_condition?
      self.keyword_rules.as_api_response(:central_publish)
    else
      []
    end
  end

  def model_changes_for_central
    @model_changes ||= previous_changes.clone.to_hash
    previous_changes.merge(@model_changes || {})
  end

  def event_info(event)
    {pod: ChannelFrameworkConfig['pod']}
  end

end