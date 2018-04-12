class Solution::Category < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |c|
    c.add :parent_id, as: :id
    c.add :name
    c.add :description
    c.add :language_id
    c.add :account_id
    c.add proc { |x| x.parent.portal_ids }, as: :portal_ids
    c.add proc { |x| x.utc_format([x.created_at, x.parent.created_at].max) }, as: :created_at
    c.add proc { |x| x.utc_format([x.updated_at, x.parent.updated_at].max) }, as: :updated_at
  end

  api_accessible :central_publish_destroy do |c|
    c.add :parent_id, as: :id
    c.add :account_id
  end

  def self.central_publish_enabled?
    Account.current.solutions_central_publish_enabled?
  end

  def model_changes_for_central
    self.previous_changes.merge!(self.parent.instance_variable_get(:@model_changes) || {})
  end

  def relationship_with_account
    :solution_categories
  end
end
