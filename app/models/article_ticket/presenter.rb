class ArticleTicket < ActiveRecord::Base
  include RepresentationHelper
  include Publish
  attr_accessor :archive_changes

  acts_as_api

  api_accessible :central_publish do |g|
    g.add :id
    g.add :article_id
    g.add :account_id
    g.add :ticketable_type
    g.add :ticketable_id
  end

  api_accessible :central_publish_destroy do |a|
    a.add :id
    a.add :account_id
    a.add :article_id
    a.add :ticketable_type
    a.add :ticketable_id
  end

  def event_info(action)
    { source_type: @interaction_source_type, source_id: @interaction_source_id } if action == :create
  end

  def model_changes_for_central
    changes_array = [previous_changes]
    changes_array << @archive_changes if defined?(@archive_changes)
    changes_array.inject(&:merge)
  end

  def relationship_with_account
    :article_tickets
  end
end
