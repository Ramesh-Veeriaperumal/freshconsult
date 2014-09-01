# 1. Authorize entire controller                                (done)
# 2. :only parameter with one action                            (done)
# 3. :only parameter with multiple actions                      (done)
# 4. :owned_by with :scoper (no :only)                          (not handled)
# 5. :owned_by with :scoper and :find_by (no :only)             (not handled)
# 6. :owned_by with :scoper with :only                          (done)
# 6. :owned_by with :scoper and :find_by with :only             (done, check!)
# 7. Have multiple combination of these in a single privilege

Authority::Authorization::PrivilegeList.build do
  
  create_project do
    resource :project, :only => [ :new, :create ]
  end
  
  edit_project do
    resource :project, :only => [ :edit, :update ],
      :owned_by => { :scoper => :projects }
  end
  
  destroy_project do
    resource :project, :only => [ :destroy ],
      :owned_by => { :scoper => :projects, :find_by => :name }
  end
  
  follow_project do
    resource :following
  end
  
  deploy_project do
    resource :deployment
  end
end