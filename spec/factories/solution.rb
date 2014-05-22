if ENV["RAILS_ENV"] == "test"
  Factory.define :solution_categories, :class => Solution::Category do |t|
    t.name "TestingSolutionCategory"
    t.description "Test for Solution Categories"
    t.is_default true
  end

  Factory.define :solution_folders, :class => Solution::Folder do |t|
    t.name "TestingSolutionCategoryFolder"
    t.description "Test for Solution Categories Folders"
    t.visibility 1
  end

  Factory.define :solution_articles, :class => Solution::Article do |t|
    t.title "TestingSolutionCategoryFolder"
    t.description "test article"
    t.folder_id 1
    t.status 2
    t.art_type 1
  end
end