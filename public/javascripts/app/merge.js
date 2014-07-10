
function MergeInitializer() {

  clearSearchField = function(entity){
  	jQuery('.search_merge').val("");
    entity.removeClass('typed');
  }

  jQuery('body').on('keyup.merge_helpdesk', '.search_merge', function(){
      jQuery(this).closest('.searchicon').toggleClass('typed', jQuery(this).val()!="");
  });

  append_to_merge_list = function(element, entity){
  	element.removeClass('cont-primary present-contact');
    element.find('.merge_element').replaceWith(entity.children('.merge_element').clone());
    element.appendTo(jQuery('.merge_entity'));
    // Commented condition was breaking ticket merge
    // console.log(entity);
    // if(!jQuery(entity).hasClass('contactdiv')){
      mark_primary(findOldestTicket());
    // }
    entity.children('#resp-icon').addClass('clicked');
  }

  jQuery('body').on('click.merge_helpdesk', '#cancel_new_merge, #cancel-user-merge', function(){
    if (active_dialog){
      active_dialog.dialog('close');
    }
    jQuery('#merge_freshdialog').modal('hide');
    jQuery('#merge_freshdialog-content').html('<span class="loading-block sloading loading-small">');
  });

  mark_primary = function(entity){
    jQuery('.merge-cont').removeClass('cont-primary');
    entity.addClass('cont-primary');
  }

  created_date = function(element){
    return element.find('.merge_element').data('created');
  }
}

function MergeDestructor() {
  jQuery('body').off('.merge_helpdesk');
}