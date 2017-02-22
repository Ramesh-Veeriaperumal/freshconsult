jQuery(document).ready(function(){	
   ProfileImage.fetch();
  if(AdminRoles && AdminRoles.new && location.pathname.includes("new")){
    AdminRoles.new.init();
  }
 else if(AdminRoles && AdminRoles.edit && location.pathname.includes("edit")){
    AdminRoles.edit.init();
  }

  else if(AdminRoles && AdminRoles.index ){
    AdminRoles.index.init();
  }

});
