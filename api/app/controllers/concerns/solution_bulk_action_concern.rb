module SolutionBulkActionConcern
  extend ActiveSupport::Concern

  include SolutionConcern

  # article methods
  def validate_bulk_update_article_params
    @constants_klass = 'SolutionConstants'.freeze
    @validation_klass = 'ArticleBulkUpdateValidation'.freeze
    return unless validate_body_params

    options = { folder_id: cname_params[:properties][:folder_id], tags: cname_params[:properties][:tags], agent_id: cname_params[:properties][:agent_id], portal_id: params[:portal_id] }
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
      article_meta.save!
      article.save! # Dummy save to trigger publishable callbacks
    end
    return true
  rescue Exception => e # rubocop:disable RescueException
    Rails.logger.debug "Error while updating article using bulk action::: #{e.message}, Account:: [#{article_meta.account_id},#{article_meta.id}]"
    return false
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
      folder_meta.add_companies(valid_companies, !(cname_params[:properties][:add_to_existing] == false)) if visibility == Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:company_users]
      folder_meta.visibility = cname_params[:properties][:visibility]
    end
  end
end
