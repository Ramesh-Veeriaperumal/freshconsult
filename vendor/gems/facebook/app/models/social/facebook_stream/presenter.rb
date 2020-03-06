class Social::FacebookStream < Social::Stream
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
    t.add :facebook_page, template: :central_publish
  end

  def relationship_with_account
    'facebook_streams'
  end

  def rules
    if send_rule_condition?
      publish_rules = []
      publish_rules.push(facebook_ticket_rules) if facebook_ticket_rules.present?
      publish_rules.as_api_response(:central_publish).flatten
    else
      []
    end
  end

  def send_rule_condition?
    if dm_stream?
      facebook_ticket_rules.present? && facebook_page.import_dms
    else
      facebook_ticket_rules.present?
    end
  end

  def model_changes_for_central
    @model_changes ||= previous_changes.clone.to_hash
    previous_changes.merge(@model_changes || {})
  end

  def event_info(_event)
    { pod: ChannelFrameworkConfig['pod'] }
  end
end
