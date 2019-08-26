class VA::Search::Conditions::SearchTransformer
  include VA::Search::Constants
  attr_accessor :conditions

  def initialize(conditions = [])
    @conditions = conditions
  end

  def to_search_format
    return if @conditions.nil?

    if nested_conditions?
      @conditions.each_with_object([]) do |condition_sets, transformed_conditions|
        transformed_conditions.push(*group_construct_conditions(condition_sets.values.first))
      end
    else
      group_construct_conditions(@conditions)
    end
  end

  private

    def group_construct_conditions(conditions)
      grouped_conditions = group_by_evaluate_on(conditions)
      grouped_conditions.each_with_object([]) do |(evaluate_on, grouped_condition_set), transformed_conditions|
        transformed_conditions.push(*klass_by_evaluate(EVALUATE_ON_MAPPING[evaluate_on.to_sym]).new(grouped_condition_set).to_search_format)
      end
    end

    def group_by_evaluate_on(conditions_sets)
      conditions_sets.group_by { |c| c[:evaluate_on] || :ticket }
    end

    def klass_by_evaluate(evaluate_on)
      "VA::Search::Conditions::#{evaluate_on.to_s.camelcase}SearchTransformer".constantize
    end

    def nested_conditions?
      @conditions.first.is_a?(Hash) && (@conditions.first.key?(:any) || @conditions.first.key?(:all))
    end
end
