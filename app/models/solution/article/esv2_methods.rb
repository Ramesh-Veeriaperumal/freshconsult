class Solution::Article < ActiveRecord::Base
  include SolutionHelper

  def to_esv2_json
    json_object = as_json({
        root: false,
        tailored_json: true,
        only: [ :title, :desc_un_html, :user_id, :status, :created_at,
                :updated_at, :thumbs_up, :thumbs_down, :account_id, :modified_at,
                :hits, :language_id, :modified_by, :outdated
              ],
        methods: [ :tag_names, :tag_ids ]
      }).merge(meta_referenced_attributes)
        .merge(es_draft_attributes)
        .merge(attachments: es_v2_attachments)
    json_object.merge!(approver_attributes) if Account.current.article_approval_workflow_enabled?
    json_object.to_json
  end

  def es_draft_attributes
    draft.present? ? draft_attr_hash(Solution::Constants::DRAFT_STATUSES_ES[:draft_present], draft.modified_by, draft.modified_at) : draft_attr_hash(Solution::Constants::DRAFT_STATUSES_ES[:draft_not_present], nil, nil)
  end

  def draft_attr_hash(status, modified_by, modified_at)
    { draft_status: draft_status, draft_modified_by: modified_by, draft_modified_at: modified_at }
  end

  def draft_status
    status = Solution::Constants::DRAFT_STATUSES_ES[:draft_not_present]
    status = Solution::Constants::DRAFT_STATUSES_ES[:draft_present] if self.draft_present?
    status = self.helpdesk_approval.try(:approval_status) if Account.current.article_approval_workflow_enabled? && self.helpdesk_approval.try(:approval_status)
    status
  end

  def tag_names
    tags.map(&:name)
  end

  def tag_ids
    tags.map(&:id)
  end

  def es_v2_attachments
    attachments.pluck(:content_file_name)
  end

  def approver_attributes
    helpdesk_approval.present? ? { approvers: helpdesk_approval.approver_mappings.pluck(:approver_id) } : { approvers: [] }
  end

  def platform_attributes
    solution_article_meta.solution_platform_mapping.present? ? solution_article_meta.solution_platform_mapping.enabled_platforms : []
  end

  # _Note_: If these attributes will be delegated in future,
  # no need to do this way
  #
  def meta_referenced_attributes
    meta_referenced_attributes = {
      art_type: solution_article_meta.art_type,
      position: solution_article_meta.position,
      folder_id: solution_folder_meta.id,
      folder_category_id: solution_folder_meta.solution_category_meta_id,
      folder_visibility: solution_folder_meta.visibility,
      company_ids: solution_folder_meta.customer_folders.pluck(:customer_id),
      contact_filter_ids: solution_folder_meta.folder_visibility_mapping.where(mappable_type: 'ContactFilter').pluck(:mappable_id),
      company_filter_ids: solution_folder_meta.folder_visibility_mapping.where(mappable_type: 'CompanyFilter').pluck(:mappable_id)
    }
    meta_referenced_attributes[:platforms] = platform_attributes if allow_chat_platform_attributes?
    meta_referenced_attributes
  end

  ##########################
  ### V1 Cluster methods ###
  ##########################

  # _Note_: Will be deprecated and remove in near future
  #
  def to_indexed_json
    article_json = as_json(
            :root => "solution/article",
            :tailored_json => true,
            :only => [ :title, :desc_un_html, :user_id, :status,
                  :language_id, :account_id, :created_at, :updated_at ],
            :include => { :tags => { :only => [:name] },
                          :attachments => { :only => [:content_file_name] }
                        }
          )
    article_json["solution/article"].merge!(meta_attributes)
    article_json.to_json
  end

  # Need to verify if it can be handled differently in v2
  #
  def related(current_portal, size = 10)
    search_key = "#{tags.map(&:name).join(' ')} #{title}"
    return [] if search_key.blank? || (search_key = search_key.gsub(/[\^\$]/, '')).blank?
    begin
      related_from_esv2(current_portal, search_key, size)
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      []
    end
  end

  def related_from_esv2(current_portal, search_term, size = 10)
    return [] if search_term.blank?

    searchparams = Hash.new.tap do |es_params|
      es_params[:search_term] = search_term
      es_params[:language_id]         = Language.current.try(:id) || Language.for_current_account.id
      es_params[:article_id]          = self.id
      es_params[:article_status]      = Solution::Constants::STATUS_KEYS_BY_TOKEN[:draft]
      es_params[:article_visibility]  = self.user_visibility
      es_params[:article_company_id]  = User.current.try(:company_ids)
      es_params[:article_category_id] = current_portal.portal_solution_categories.map(&:solution_category_meta_id)

      es_params[:size]                = 10
      es_params[:from]                = 0
    end

    Search::V2::QueryHandler.new({
      account_id:   Account.current.id,
      context:      :portal_related_articles,
      exact_match:  Search::Utils.exact_match?(searchparams[:search_term]),
      es_models:    { 'article' => { model: 'Solution::Article', associations: []}},
      current_page: Search::Utils::DEFAULT_PAGE,
      offset:       0,
      types:        ['article'],
      es_params:    ({
        account_id: Account.current.id,
        request_id: Thread.current[:message_uuid].try(:first) #=> Msg ID is casted as array.
      }).merge(searchparams)
    }).query_results
  end
end
