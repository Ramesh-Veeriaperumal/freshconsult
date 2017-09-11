module Freshcaller::SearchTestHelper
  def contact_search_results_pattern
    {
      :results => [{
        'value': 'Lorem',
        'id': 1
      }]
    }
  end

  def empty_contact_search_results_pattern
    {
      :results => []
    }
  end

  def contact_search_response_pattern
    [{
      "id" => 1,
      "name" => "Lorem",
      "phone" => nil,
      "mobile" => nil,
      "company" => nil
    }]
  end
end
