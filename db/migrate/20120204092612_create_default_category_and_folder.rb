class CreateDefaultCategoryAndFolder < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      default_category = account.solution_categories.new({:name=> I18n.t('default_category'), :description=> I18n.t("default_category_description", :full_domain => account.kbase_email), :is_default => true})
      default_category.save
      default_category.move_to_top
      
      default_folder = default_category.folders.new({:name=>I18n.t('default_folder'), :description=>I18n.t('default_folder_description', :full_domain => account.kbase_email), :visibility=>"3", :is_default => true}) 
      default_folder.category_id = default_category.id
      default_folder.save
    end
  end

  def self.down
    Account.all.each do |account|
      default_category = account.solution_categories.find_by_is_default(true)
      default_category.move_to_bottom
      default_category.destroy
    end
  end
end
