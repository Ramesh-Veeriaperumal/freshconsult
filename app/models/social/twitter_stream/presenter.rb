class Social::TwitterStream < Social::Stream
  include RepresentationHelper
  acts_as_api
  api_accessible :central_publish do |t|
    t.add :account_id
    t.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    t.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
    t.add proc { |x| x.data[:kind].downcase }, as: :type
    t.add :rules
    t.add :id

  end

  api_accessible :central_publish_associations do |t|
    t.add :twitter_handle, template: :central_publish
  end

  def relationship_with_account
    'twitter_streams'
  end

  def send_rule_condition?
    if data[:kind] == 'DM'
      keyword_rules.present? && keyword_rules.first.action_data[:capture_dm_as_ticket]
    elsif data[:kind] == 'Mention'
      keyword_rules.present? || smart_filter_rule.present?
    end
  end

  def rules
    if send_rule_condition?
      ticket_rules = []
      ticket_rules.push(keyword_rules) if keyword_rules.present?
      ticket_rules.push(smart_filter_rule) if smart_filter_rule.present?
      ticket_rules.as_api_response(:central_publish).flatten
    else
      []
    end
  end

  def model_changes_for_central
    @model_changes[:rules][0] = @backup_model_changes if @backup_model_changes.present?
    @model_changes[:rules][1] = Account.current.twitter_streams.find_by_id(id).rules
    @model_changes ||= previous_changes.clone.to_hash
    previous_changes.merge(@model_changes || {})
  end

  def event_info(event)
    {pod: ChannelFrameworkConfig['pod']}
  end

end