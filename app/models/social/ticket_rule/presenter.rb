class Social::TicketRule < ActiveRecord::Base
  include RepresentationHelper
  acts_as_api
  api_accessible :central_publish do |t|
    t.add :account_id
    t.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    t.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
    t.add :rule_kind, as: :type
    t.add proc { |x| x.action_data.except(:capture_dm_as_ticket, :with_keywords) }, as: :action
    t.add proc { |x| x.filter_data }, as: :filter_data, if: :keyword_rule?
    t.add :stream_id
    t.add :id
  end

  def rule_kind
    if type == 'DM'
      'all'
    elsif type == 'Mention' && rule_type.blank?
      'keyword_filter'
    elsif rule_type == 7
      'smart_filter'
    end
  end

  def keyword_rule?
    ['Mention', 'Ad_post'].include?(type) && rule_type.blank?
  end
end
