function clearSearchField(entity){
	jQuery('.search_merge').val("");
  entity.removeClass('typed');
}

jQuery('.search_merge').bind('keyup', function(){
    jQuery('.searchicon').toggleClass('typed', jQuery(this).val()!="");
});

function append_to_merge_list(element, entity){
	element.removeClass('cont-primary present-contact');
  element.find('.merge_element').replaceWith(entity.children('.merge_element').clone());
  element.appendTo(jQuery('.merge_entity'));
  entity.children('#resp-icon').addClass('clicked');
}

jQuery('#cancel_new_merge').bind('click', function(){
  active_dialog.dialog('close');
});

jQuery('#cancel-user-merge').live('click', function(){
  active_dialog.dialog('close');
});

function mark_primary(entity){
  jQuery('.merge-cont').removeClass('cont-primary');
  entity.parent().addClass('cont-primary');
}