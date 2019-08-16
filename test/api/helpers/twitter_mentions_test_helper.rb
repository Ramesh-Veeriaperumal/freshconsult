module TwitterMentionsTestHelper
  def create_smart_filter_rule(stream)
    rule = FactoryGirl.build(:seed_social_filter_rules)
    rule.account_id = @account.id
    rule.stream_id = stream.id
    rule.rule_type = 7
    rule.save
    rule
  end

  def mention_stream_publish_pattern(stream)
    {
      account_id: @account.id,
      created_at: stream.created_at.try(:utc).try(:iso8601),
      updated_at: stream.updated_at.try(:utc).try(:iso8601),
      type: 'mention',
      rules: stream.rules,
      id: stream.id
    }
  end

  def construct_stream_update_params(stream)
    {
      visible_to: ['4'],
      capture_tweet_as_ticket: '1',
      capture_dm_as_ticket: '0',
      keyword_rules: '1',
      smart_filter_enabled: '0',
      dm_rule: { group_assigned: '' },
      social_ticket_rule: [{ ticket_rule_id: '', deleted: 'false', includes: 'test,testing', group_id: '' }],
      social_twitter_handle: { dm_thread_time: '28800' },
      smart_filter_rule_without_keywords: { ticket_rule_id: '', group_id: '' },
      smart_filter_rule_with_keywords: { ticket_rule_id: '', group_id: '' },
      id: stream.id.to_s
    }
  end
end
