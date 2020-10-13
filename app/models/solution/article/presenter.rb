class Solution::Article < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |a|
    a.add :id, as: :article_id
    a.add :parent_id, as: :id
    a.add :title
    a.add :description
    a.add :account_id
    a.add :desc_un_html, as: :description_text
    a.add :status
    # created_by
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
    a.add :outdated
    a.add proc { |x| x.utc_format([x.updated_at, x.parent.updated_at].max) }, as: :updated_at
    a.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    a.add proc { |x| x.utc_format(x.modified_at) }, as: :modified_at
    a.add :modified_by
    a.add proc { |x| x.draft_present? ? 1 : 0 }, as: :draft_exists
    a.add proc { |x| x.utc_format(x.draft.try(:modified_at)) }, as: :draft_modified_at
    a.add proc { |x| x.draft.try(:user_id) }, as: :draft_modified_by
    a.add proc { |x| x.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published] ? x.utc_format(x.modified_at) : nil }, as: :published_at
    a.add proc { |x| x.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published] ? x.modified_by : nil }, as: :published_by
    if proc { Account.current.article_approval_workflow_enabled? }
      a.add proc { |x| x.helpdesk_approval.try(:approval_status) }, as: :approval_status
      a.add proc { |x| x.helpdesk_approval.try(:approved_by) }, as: :approved_by
      a.add proc { |x| x.utc_format(x.helpdesk_approval.try(:approved_at)) }, as: :approved_at
    end
  end

  api_accessible :central_publish_destroy do |a|
    a.add :parent_id, as: :id
    a.add :id, as: :article_id
    a.add :account_id
    a.add :language_code
    a.add :title
  end

  api_accessible :article_interactions do |a|
    a.add :parent_id, as: :id
    a.add :id, as: :article_id
    a.add proc { |x| x.parent.thumbs_up }, as: :thumbs_up
    a.add proc { |x| x.parent.thumbs_down }, as: :thumbs_down
    a.add proc { |x| x.parent.hits }, as: :hits
    a.add :thumbs_up, as: :article_thumbs_up
    a.add :thumbs_down, as: :article_thumbs_down
    a.add :hits, as: :article_hits
    a.add :suggested, as: :article_suggested
    a.add :account_id
  end

  def event_info(action)
    event_info = { ip_address: Thread.current[:current_ip] }
    if action == :interactions
      event_info.merge!(source_type: @interaction_source_type, source_id: @interaction_source_id)
      event_info.merge!(platform: @interaction_platform) unless @interaction_platform.nil?
    end
    event_info
  end

  def central_publish_worker_class
    'CentralPublishWorker::SolutionArticleWorker'
  end

  def column_attribute_mapping
    # Since name in payload is change, need to change in model changes also
    {
      user_id: :agent_id
    }
  end

  def model_changes_for_central
    update_publish_details
    update_unpublish_details
    column_attribute_mapping.each_pair do |key, val| 
      previous_changes[val] = previous_changes.delete(key) if previous_changes.key?(key)
    end
    changes_array = [previous_changes, parent.previous_changes, article_body.previous_changes]
    changes_array << @model_changes if @model_changes
    changes_array << { tags: tag_changes } if tag_changes
    changes_array.inject(&:merge)
  end

  def misc_changes_for_central
    changes_array = [folder_update_details, author_update_details]
    changes_array.reduce(&:merge)
  end

  def relationship_with_account
    :solution_articles
  end

  def payload_template_mapping
    {
      article_interactions: :article_interactions
    }.with_indifferent_access
  end
end
