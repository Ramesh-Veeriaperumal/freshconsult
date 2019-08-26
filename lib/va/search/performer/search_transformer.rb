class VA::Search::Performer::SearchTransformer
  attr_accessor :performer

  def initialize(performer = {})
    @performer = performer
  end

  def to_search_format
    performer_transformed_text = "type:#{@performer.type}"
    if @performer.members.present?
      @performer.members.map { |member| "#{performer_transformed_text}:member:#{member}" }
    else
      [performer_transformed_text]
    end
  end
end