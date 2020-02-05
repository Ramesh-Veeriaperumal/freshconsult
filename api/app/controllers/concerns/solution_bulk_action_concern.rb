module SolutionBulkActionConcern
  extend ActiveSupport::Concern

  include SolutionConcern
  include SolutionApprovalConcern

  # article methods
  def validate_bulk_update_article_params
    @constants_klass = 'SolutionConstants'.freeze
    @validation_klass = 'ArticleBulkUpdateValidation'.freeze
    return unless validate_body_params

    options = { folder_id: cname_params[:properties][:folder_id], tags: cname_params[:properties][:tags], agent_id: cname_params[:properties][:agent_id], portal_id: params[:portal_id], approval_status: cname_params[:properties][:approval_status], approver_id: cname_params[:properties][:approver_id], status: cname_params[:properties][:status] }
    @delegator = ApiSolutions::ArticleBulkUpdateDelegator.new(options)
    return true if @delegator.valid?(action_name.to_sym)

    render_custom_errors(@delegator, true)
  end

  def tags
    @tags ||= (cname_params[:properties][:tags] || []).map { |tag| Helpdesk::Tag.where(name: tag, account_id: Account.current.id).first_or_create }
  end

  def update_article_properties(article_meta)
    ActiveRecord::Base.transaction do
      update_folder(article_meta)
      article = article_meta.safe_send(language_scoper)
      update_tags(article)
      update_author(article)
      update_outdated(article)
      raise 'Approval updation failed!' unless update_article_approval(article)
      raise 'Review request failed!' unless update_send_for_review(article)
      raise 'Status updation failed!' if !update_status(article)
      article_meta.save!
    end
    return true
  rescue Exception => e # rubocop:disable RescueException
    Rails.logger.debug "Error while updating article using bulk action::: #{e.message}, Account:: [#{article_meta.account_id},#{article_meta.id}]"
    return false
  end

  def update_article_approval(article)
    if cname_params[:properties][:approval_status].present? && cname_params[:properties][:approval_status].to_i == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
      unless article.helpdesk_approval.nil?
        helpdesk_approval_record = article.helpdesk_approval
        helpdesk_approver_mapping = get_or_build_approver_mapping(helpdesk_approval_record, User.current.id)
        helpdesk_approver_mapping.approve!
      end
    end
    true
  end

  def update_tags(article)
    if cname_params[:properties][:tags].present?
      old_tags = article.save_tags
      tags.each { |tag| article.tags << tag unless old_tags.include?(tag.name) }
    end
  end

  def update_author(article)
    article.user_id = cname_params[:properties][:agent_id] if cname_params[:properties][:agent_id]
  end

  def update_folder(article_meta)
    article_meta.solution_folder_meta_id = cname_params[:properties][:folder_id] if cname_params[:properties][:folder_id]
  end

  # folder methods
  def validate_bulk_update_folder_params
    @constants_klass = 'SolutionConstants'.freeze
    @validation_klass = 'FolderBulkUpdateValidation'.freeze
    return unless validate_body_params

    options = { category_id: cname_params[:properties][:category_id], visibility: cname_params[:properties][:visibility], company_ids: cname_params[:properties][:company_ids] }
    @delegator = ApiSolutions::FolderBulkUpdateDelegator.new(options)
    return true if @delegator.valid?(action_name.to_sym)

    render_custom_errors(@delegator, true)
  end

  def valid_companies
    @valid_companies ||= Account.current.companies.where(id: cname_params[:properties][:company_ids]).pluck(:id) if cname_params[:properties][:company_ids].present?
  end

  def update_folder_properties(folder_meta)
    ActiveRecord::Base.transaction do
      update_category(folder_meta)
      update_visibility(folder_meta)
      folder_meta.save!
      folder_meta.primary_folder.save!
    end
    return true
  rescue Exception => e # rubocop:disable RescueException
    Rails.logger.debug "Error while updating folder using bulk action::: #{e.message}, Account:: [#{folder_meta.account_id},#{folder_meta.id}] "
    return false
  end

  def update_category(folder_meta)
    folder_meta.solution_category_meta_id = cname_params[:properties][:category_id] if cname_params[:properties][:category_id]
  end

  def update_visibility(folder_meta)
    visibility = cname_params[:properties][:visibility]
    if visibility
      folder_meta.add_companies(valid_companies, cname_params[:properties][:add_to_existing] != false) if visibility == Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:company_users]
      folder_meta.visibility = cname_params[:properties][:visibility]
    end
  end

  def update_status(article)
    if cname_params[:properties][:status] == Solution::Constants::STATUS_KEYS_BY_TOKEN[:published]
      return false if article.draft.blank? || article.draft.locked? || article.solution_folder_meta.is_default?

      # validate_publish_approved_solution_permission
      if Account.current.article_approval_workflow_enabled? && User.current.privilege?(:publish_approved_solution) && !User.current.privilege?(:publish_solution)
        return false if article.helpdesk_approval.nil? || article.helpdesk_approval.approval_status != Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
      end
      article.draft.publish! if article.draft.present?
    end
    true
  end

  def update_outdated(article)
    article.outdated = cname_params[:properties][:outdated] if cname_params[:properties].key?(:outdated)
  end

  def update_send_for_review(article)
    if cname_params[:properties].key?(:approval_status) && cname_params[:properties].key?(:approver_id)
      return false if article.draft.blank? || article.draft.locked? || article.solution_folder_meta.is_default?

      helpdesk_approval = get_or_build_approval_record(article)
      get_or_build_approver_mapping(helpdesk_approval, cname_params[:properties][:approver_id])
      helpdesk_approval.save!
    end
    true
  end
end
