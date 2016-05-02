require_relative '../test_helper'

class Search::V2::SolutionsControllerTest < ActionController::TestCase

  def setup
    super
    @ticket = @account.tickets.first
    @request.env["HTTP_ACCEPT"] = 'application/x-javascript'
  end

  def test_related_solutions_template
    get :related_solutions, :ticket => @ticket.id
    assert_template('search/solutions/related_solutions')
  end

  def test_search_solutions_template
    get :search_solutions, :ticket => @ticket.id
    assert_template('search/solutions/search_solutions')
  end
end