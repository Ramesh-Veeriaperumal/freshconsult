class VA::Search::Actions::SearchTransformer
  include VA::Search::VaRuleSearchTransformer
  attr_accessor :actions, :type

  def initialize(actions = [])
    @type = :action
    @actions = actions
  end

  def to_search_format
    @actions.each_with_object([]) do |action, actions_array|
      tranformed_data = construct_search_hash(action.deep_symbolize_keys)
      tranformed_data.each do |data|
        actions_array.push(data.values.join(':'))
      end
    end
  end

  private

    def handle_value(value, field_name = nil)
      if value.present? && field_name == :add_tag
        value.split(',').map(&:strip)
      else
        [*value]
      end
    end
end
