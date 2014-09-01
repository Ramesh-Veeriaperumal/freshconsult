module Import::Zen::Group

 class GroupProp < Import::FdSax  
   element :name
   element :id , :as => :import_id
 end

 def save_group group_xml
  group_prop = GroupProp.parse(group_xml)
  group = @current_account.groups.find(:first, :conditions =>['name=? or import_id=?',group_prop.name,group_prop.import_id])
  unless group
    group = @current_account.groups.create(group_prop.to_hash)
  else
    group.update_attribute(:import_id , group_prop.import_id )
  end
end

end