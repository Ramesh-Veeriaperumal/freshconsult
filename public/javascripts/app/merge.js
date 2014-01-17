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
    mark_primary(findOldestTicket());
    entity.children('#resp-icon').addClass('clicked');
  }

  jQuery('body').on('click.merge_helpdesk', '#cancel_new_merge, #cancel-user-merge', function(){
    active_dialog.dialog('close');
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