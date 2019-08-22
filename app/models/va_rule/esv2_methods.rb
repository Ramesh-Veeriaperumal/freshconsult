class VaRule < ActiveRecord::Base
  def to_esv2_json
    as_json(
      root: false,
      tailored_json: true,
      only: [:id, :account_id, :name, :created_at, :updated_at,
             :rule_type, :active, :outdated],
      methods: [:updated_by]
    ).merge(additional_params).to_json
  end

  def additional_params
    {
      actions: search_actions,
      conditions: search_conditions,
      performer: search_performer,
      events: search_events
    }
  end

  def search_actions
    VA::Search::Actions::SearchTransformer.new(action_data).to_search_format
  end

  def search_conditions
    VA::Search::Conditions::SearchTransformer.new(condition_sets).to_search_format
  end

  def search_performer
    observer_rule? ? VA::Search::Performer::SearchTransformer.new(rule_performer).to_search_format : []
  end

  def search_events
    observer_rule? ? VA::Search::Events::SearchTransformer.new(rule_events).to_search_format : []
  end
end
