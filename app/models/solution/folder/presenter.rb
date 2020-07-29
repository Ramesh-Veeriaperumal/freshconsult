class Solution::Folder < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |f|
    f.add :id, as: :folder_id
    f.add proc { |x| x.parent_id }, as: :id
    f.add :name
    f.add :description
    f.add :language_id
    f.add :language_code
    f.add :account_id
    f.add proc { |x| x.parent.visibility }, as: :visibility
    f.add proc { |x| x.parent.article_order }, as: :article_order
    f.add proc { |x| x.parent.solution_category_meta_id }, as: :category_id
    f.add proc { |x| x.utc_format([x.created_at, x.parent.created_at].max) }, as: :created_at
    f.add proc { |x| x.utc_format([x.updated_at, x.parent.updated_at].max) }, as: :updated_at
  end

  api_accessible :central_publish_destroy do |f|
    f.add :id, as: :folder_id
    f.add :parent_id, as: :id
    f.add :account_id
    f.add :language_code
    f.add :name
  end

  def relationship_with_account
    :solution_folders
  end

  def misc_changes_for_central
    category_update_details
  end

  def model_changes_for_central
    self.previous_changes.merge(self.parent.previous_changes)
  end

  def event_info(_action)
    { ip_address: Thread.current[:current_ip] }
  end
end
