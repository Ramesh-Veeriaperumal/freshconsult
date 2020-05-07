class ArticleTicket < ActiveRecord::Base
  include RepresentationHelper
  include Publish
  attr_accessor :archive_changes

  DATETIME_FIELDS = [:created_at, :updated_at].freeze

  acts_as_api

  api_accessible :central_publish do |g|
    g.add :id
    g.add :article_id
    g.add :account_id
    g.add :ticketable_type
    g.add :ticketable_id

    DATETIME_FIELDS.each do |key|
      g.add proc { |x| x.utc_format(x.ticketable.send(key)) }, as: key
    end
  end

  api_accessible :central_publish_destroy do |a|
    a.add :id
    a.add :account_id
    a.add :article_id
    a.add :ticketable_type
    a.add :ticketable_id
  end

  def self.central_publish_enabled?
    Account.current.solutions_central_publish_enabled?
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
