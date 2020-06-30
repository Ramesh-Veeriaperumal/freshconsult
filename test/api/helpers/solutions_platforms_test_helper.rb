require_relative '../../core/helpers/solutions_test_helper.rb'

module SolutionsPlatformsTestHelper
  include SolutionsArticlesTestHelper
  include Helpdesk::TagMethods

  def get_folder_with_platform_mapping(platform_values = {})
    folder_meta = get_folder_meta_without_platform_mapping
    folder_meta.visibility = 1
    folder_meta.create_solution_platform_mapping(chat_platform_params(platform_values, true))
    folder_meta.save!
    folder_meta.reload
    folder_meta.children.first
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

  def chat_platform_params(platform_values = {}, default = false)
    {
      web: platform_values.key?(:web) ? platform_values[:web] : default,
      ios: platform_values.key?(:ios) ? platform_values[:ios] : default,
      android: platform_values.key?(:android) ? platform_values[:android] : default
    }
  end
end
