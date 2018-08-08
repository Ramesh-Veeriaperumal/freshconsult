class Segments::Match::Base
  def initialize(evaluate_on, options = {})
    @evaluate_on = evaluate_on
    raise ArgumentError, 'evaluate_on cannot be nil' if evaluate_on.nil?
    @conditions = {}
    @matching_segments = {}
    initialize_options(options)
  end

  def any?(options = {})
    perform options
    response(:any?)
  end

  def all?(options = {})
    perform options
    response(:all?)
  end

  def ids(options = {})
    perform options
    response(:select).keys
  end

  def all(options = {})
    segment_ids = ids(options)
    @segments.select { |segment| segment_ids.include?(segment.id) }
  end

  def segments
    @segments = if @segment_ids.present?
                  @segment_ids = [*@segment_ids].map(&:to_i)
                  account_segments.select { |s| @segment_ids.include?(s.id) }
                else
                  account_segments
                end
  end

  private

    def perform(options = {})
      initialize_options(options)
      segments.each do |segment|
        segment_conditions = conditions(segment)
        @matching_segments[segment.id] ||= segment_conditions.all? do |c|
          to_ret = Time.use_zone(account.time_zone) do
            c.matches @evaluate_on
          end
          Rails.logger.debug "#{self.class.inspect} rule_matches [1] - C=#{@evaluate_on.id} :: S=#{segment.id} :: #{c.inspect} :: #{to_ret}"
          to_ret
        end
      end
    end

    def conditions(segment)
      @conditions[segment.id] ||= segment.transformed_data.map do |condition|
        RuleEngine::Condition.new(condition, @type)
      end
    end

    def initialize_options(options)
      options.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    def response(method)
      ids ||= @segments.map(&:id)
      @matching_segments.safe_send(method) do |segment_id, result|
        result && ids.include?(segment_id)
      end
    end

    def account
      @account ||= Account.current
    end
end
