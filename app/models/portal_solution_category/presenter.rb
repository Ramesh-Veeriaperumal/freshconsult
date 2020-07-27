class PortalSolutionCategory < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |g|
    g.add :id
    g.add :portal_id
    g.add :account_id
    g.add :solution_category_meta_id
    g.add :bot_id
  end

  api_accessible :central_publish_destroy do |a|
    a.add :id
    a.add :account_id
    a.add :portal_id
    a.add :solution_category_meta_id
  end

  def model_changes_for_central
    changes_array = [previous_changes]
    changes_array.inject(&:merge)
  end

  def relationship_with_account
    :portal_solution_categories
  end

  def event_info(_action)
    { ip_address: Thread.current[:current_ip] }
  end
end
