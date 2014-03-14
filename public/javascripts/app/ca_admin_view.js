
ticksymbol = "<span class='ticksymbol'></span>";

jQuery(".ca_text").text(jQuery("#folder1").text());

jQuery("#new_resp").bind('click', function(ev){
	ev.preventDefault();
	window.location = '/admin/canned_responses/folders/'+folder_id+'/responses/new';
})

jQuery("#responses-select-all").live("change", function(ev){
	jQuery("#responses").find("input[type=checkbox]").prop("checked", jQuery(this).prop("checked")).trigger('change');
	jQuery("#responses").trigger('click');
});

jQuery("#responses").click(function() {
			var checkStatus = jQuery('#resp-boxes :checked').size();
            if (checkStatus > 0) 
            {
                jQuery('#move, #admin_canned_response_submit').removeAttr('disabled');
            } 
            else 
            {
                jQuery('#move, #admin_canned_response_submit').attr('disabled', 'disabled');
            }
});

jQuery('#resp-boxes input[type=checkbox]').live('change', function(){
	if (jQuery(this).prop('checked'))
		jQuery(this).parent().parent().addClass('selected_resp');
	else
		jQuery(this).parent().parent().removeClass('selected_resp');
	jQuery('#responses-select-all').prop('checked', jQuery('#responses :checkbox:checked').length == jQuery('#responses :checkbox').length);
});

jQuery("[data-folder]").live('click', function(){
	folder_id=jQuery(this).data('folder');
	jQuery('#responses-select-all').removeAttr('disabled');
	makeFolderActive(folder_id);
});

var makeFolderActive = function(folder_id) {
	url = ca_path+folder_id;
	if(!jQuery('[data-folder='+folder_id+']').hasClass('default-folder'))
		jQuery('#edit-ca-folder, #del').show();
	jQuery('#move, #admin_canned_response_submit').attr('disabled', 'disabled');
	jQuery('#folder_edit_form').attr('action', url);
	jQuery(".catch").css("font-weight","normal").find('.ticksymbol').remove();
	jQuery('.catch').removeClass('selected-folder');
	jQuery('[data-folder='+folder_id+']').css("font-weight","bold").prepend(ticksymbol).addClass('selected-folder');
	var tes = jQuery('[data-folder='+folder_id+']').text();
	jQuery(".ca_text").text(tes);	
	jQuery('#admin_canned_responses_folder_name').val(jQuery('[data-folder='+folder_id+']').data('name'));
	if(jQuery('#responses-select-all').prop("checked"))
		jQuery('#responses-select-all').click();
}

jQuery(".default-folder").live('click', function(){
	jQuery('#edit-ca-folder, #del').hide();
});

makeFolderActive(folder_id);
