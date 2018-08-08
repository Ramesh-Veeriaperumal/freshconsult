class Segments::Match::Contact < Segments::Match::Base
  def initialize(evaluate_on, options = {})
    @type = :contact
    super evaluate_on, options
  end

  private

    def account_segments
      @account_segments ||= account.contact_filters_from_cache
    end
end
