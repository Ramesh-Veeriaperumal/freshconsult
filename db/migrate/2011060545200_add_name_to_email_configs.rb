class AddNameToEmailConfigs < ActiveRecord::Migration
  def self.up
    #add_column :email_configs, :name, :string
    
    #Account.all.each do |account|
      #name = account.helpdesk_name.blank? ? account.name : account.helpdesk_name
      
      #account.primary_email_config.update_attributes!(:name => name)
      #account.products.each_with_index do |p, i|
       # p.update_attributes!(:name => "#{name} #{i+1}")
      #end
    #end
  end

  def self.down
    remove_column :email_configs, :name
  end
end
