class Segments::Match::Company < Segments::Match::Base
  def initialize(evaluate_on, options = {})
    @type = :company
    super evaluate_on, options
  end

  private

    def account_segments
      @account_segments ||= account.company_filters_from_cache
    end
end
