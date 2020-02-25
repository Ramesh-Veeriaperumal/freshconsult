class Solution::Article < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |a|
    a.add :parent_id, as: :id
    a.add :title
    a.add :description
    a.add :account_id
    a.add :desc_un_html, as: :description_text
    a.add :status
    a.add :user_id, as: :agent_id
    a.add proc { |x| x.parent.art_type }, as: :type
    a.add proc { |x| x.parent.solution_category_meta.id }, as: :category_id
    a.add proc { |x| x.parent.solution_folder_meta_id }, as: :folder_id
    a.add proc { |x| x.parent.thumbs_up }, as: :thumbs_up
    a.add proc { |x| x.parent.thumbs_down }, as: :thumbs_down
    a.add proc { |x| x.parent.hits }, as: :hits
    a.add :tags
    a.add :seo_data
    a.add :language_id
    a.add :language_code
    a.add :account_id
    a.add proc { |x| x.utc_format([x.created_at, x.parent.created_at].max) }, as: :created_at
    a.add proc { |x| x.utc_format([x.updated_at, x.parent.updated_at].max) }, as: :updated_at
  end

  api_accessible :central_publish_destroy do |a|
    a.add :parent_id, as: :id
    a.add :account_id
    a.add :language_code
  end

  api_accessible :votes do |a|
    a.add :parent_id, as: :id
    a.add proc { |x| x.parent.thumbs_up }, as: :thumbs_up
    a.add proc { |x| x.parent.thumbs_down }, as: :thumbs_down
    a.add :account_id
    a.add proc { |x| x.utc_format([x.created_at, x.parent.created_at].max) }, as: :created_at
    a.add proc { |x| x.utc_format([x.updated_at, x.parent.updated_at].max) }, as: :updated_at
  end

  def self.central_publish_enabled?
    Account.current.solutions_central_publish_enabled?
  end

  def model_changes_for_central
    changes_array = [self.previous_changes, self.parent.previous_changes, self.article_body.previous_changes]
    changes_array.inject(&:merge)
  end

  def relationship_with_account
    :solution_articles
  end

  def payload_template_mapping
    {
      article_thumbs_up: :votes,
      article_thumbs_down: :votes
    }.with_indifferent_access
  end
end
