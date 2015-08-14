if Rails.env.test?
  FactoryGirl.define do
    factory :solution_categories, :class => Solution::Category do
      name "TestingSolutionCategory"
      description "Test for Solution Categories"
      is_default true
    end

    factory :solution_folders, :class => Solution::Folder do
      name "TestingSolutionCategoryFolder"
      description "Test for Solution Categories Folders"
      visibility 1
      is_default false
    end

    factory :solution_articles, :class => Solution::Article do
      title "TestingSolutionCategoryFolder"
      description "test article"
      folder_id 1
      status 2
      art_type 1
    end
  end
end