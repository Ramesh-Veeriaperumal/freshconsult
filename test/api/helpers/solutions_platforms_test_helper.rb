require_relative '../../core/helpers/solutions_test_helper.rb'

module SolutionsPlatformsTestHelper
  include SolutionsArticlesTestHelper
  include SolutionsApprovalsTestHelper
  include Helpdesk::TagMethods
  include AttachmentsTestHelper

  def get_article_with_platform_mapping(platform_values = {})
    article = get_article_without_platform_mapping
    article.parent.create_solution_platform_mapping(chat_platform_params(platform_values, true))
    article
  end

  def get_article_without_draft_with_platform_mapping(platform_values = {})
    article = get_article_without_draft
    article.parent.create_solution_platform_mapping(chat_platform_params(platform_values, true))
    article
  end

  def get_article_without_platform_mapping
    article = get_article_with_platform_enabled_in_folder
    article.parent.solution_platform_mapping.destroy if article.parent.solution_platform_mapping.present?
    article.reload
  end

  def get_article_with_platform_enabled_in_folder
    article = get_article_without_draft
    create_platform_mapping_for_associated_folder(article)
    article
  end

  def get_in_review_article_with_platform_mapping
    article = get_in_review_article
    create_platform_mapping_for_associated_folder(article)
    article
  end

  def get_articles_enabled_in_platforms_count(platforms)
    conditions = ['solution_platform_mappings.mappable_type = \'Solution::ArticleMeta\'']
    platform_condition = platforms.map { |platform_type| "solution_platform_mappings.#{platform_type} = true" }.join(' OR ')
    conditions << format('(%{platform_criteria})', platform_criteria: platform_condition)

    Account.current.solution_platform_mappings.where(conditions.join(' AND ')).size
  end

  def get_folder_meta_with_platform_mapping(platform_values = {})
    folder_meta = get_folder_meta_without_platform_mapping
    folder_meta.create_solution_platform_mapping(chat_platform_params(platform_values, true))
    folder_meta
  end

  def get_folder_with_platform_mapping(platform_values = {})
    folder_meta = get_folder_meta_without_platform_mapping
    folder_meta.visibility = 1
    folder_meta.create_solution_platform_mapping(chat_platform_params(platform_values, true))
    folder_meta.save!
    folder_meta.reload
    folder_meta.children.first
  end

  def get_folder_with_icon
    folder_meta = get_folder_meta_without_platform_mapping
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
    icon = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: User.current.id)
    folder_meta.icon = icon
    folder_meta.save!
    folder_meta.reload
    folder_meta
  end

  def get_folder_with_platform_mapping_and_tags(platform_values = {}, tag_array = [])
    folder_meta = get_folder_meta_without_platform_mapping
    folder_meta.create_solution_platform_mapping(chat_platform_params(platform_values, true))
    tag_objects = construct_tags(tag_array)
    folder_meta.tags = tag_objects
    folder_meta.save!
    folder_meta.reload
    folder_meta.children.first
  end

  def get_folder_meta_without_platform_mapping
    folder_meta = @account.solution_folder_meta.where(is_default: false).first
    folder_meta.solution_platform_mapping.destroy if folder_meta.solution_platform_mapping.present?
    folder_meta.reload
  end

  def filter_folders_by_platforms(platforms = ['web', 'ios', 'android'], language = Account.current.language_object, folders = @account.solution_folders)
    folders.select { |folder| folder.language_id == language.id && folder.parent.solution_platform_mapping.present? && (folder.parent.solution_platform_mapping.enabled_platforms - platforms).present? }
  end

  def filter_folders_by_tags(tag_names, language = Account.current.language_object, folders = @account.solution_folders)
    folders.select { |folder| folder.language_id == language.id && folder.parent.tags.where(name: tag_names).first }
  end

  def update_platform_values(meta_obj, values)
    meta_obj.solution_platform_mapping.attributes = values
    meta_obj.save
    meta_obj
  end

  def enable_omni_bundle
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    yield
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback(:kbase_omni_bundle)
  end

  def chat_platform_params(platform_values = {}, default = false)
    {
      web: platform_values.key?(:web) ? platform_values[:web] : default,
      ios: platform_values.key?(:ios) ? platform_values[:ios] : default,
      android: platform_values.key?(:android) ? platform_values[:android] : default
    }
  end

  def omni_bundle_required_error_for_platforms
    bad_request_error_pattern('platforms', :require_feature, feature: :omni_bundle_2020, code: :access_denied)
  end

  private

    def create_platform_mapping_for_associated_folder(article)
      folder_meta = article.solution_folder_meta
      folder_meta.create_solution_platform_mapping(chat_platform_params({}, true)) if folder_meta.solution_platform_mapping.blank?
    end
end
