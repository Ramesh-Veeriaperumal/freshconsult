
ticksymbol = "<span class='ticksymbol'></span>";

jQuery("#menu-block").text(jQuery("#folder1").text());

jQuery("#new_resp").bind('click', function(ev){
	ev.preventDefault();
	window.location = '/admin/canned_responses/folders/'+folder_id+'/responses/new';
})


function edit_setting(){
	jQuery('#folder_edit_form').toggleClass('shown');
	jQuery('#editing').dialog({
		position : "top", 
		title : "Rename Folder", 
		draggable : false, 
		modal : true, 
		width : 510,
		resizable : false,
		close: function(ev,ui){
			jQuery('#folder_edit_form').toggleClass('shown');
		}
	});
}

jQuery('#edit-ca-folder').bind('click', function(){
	edit_setting();
});

jQuery('#edit-cancel').bind('click', function(ev){
	ev.preventDefault();
	jQuery('#editing').dialog('close');
});

jQuery('#save_edit').bind('click', function(ev){
	if(jQuery.browser.opera || jQuery.browser.msie)
	{
		jQuery('#folder_edit_form').submit();
	}
});

jQuery('#save_edit').bind('click', function(ev){
	if(jQuery.browser.opera || jQuery.browser.msie)
	{
		jQuery('#folder_edit_form').submit();
	}
});

jQuery("#responses-select-all").live("change", function(ev){
	jQuery("#responses").find("input[type=checkbox]").prop("checked", jQuery(this).prop("checked")).trigger('change');
	jQuery("#responses").trigger('click');
});


jQuery("#move").bind('click', function(ev){
	ev.preventDefault();
	jQuery("#moves").dialog({
		position : "top", 
		title : "Move to folder", 
		draggable : false, 
		modal : true, 
		resizable : false
		});
});

jQuery('#cancel-move').bind('click', function(){
	jQuery('#moves').dialog('close');
});

jQuery('#del').live('click', function(ev)
{
	ev.preventDefault();
	jQuery('#folder-delete').dialog({
		position : "top", 
		title : "Delete folder", 
		draggable : false, 
		modal : true, 
		resizable : false,
		width : 510
	});
	jQuery('#confirm-delete').bind('click', function(){
		console.log(jQuery('#del').attr('href'));
		console.log(jQuery('#del').data("method"));
		jQuery('#confirm-delete').attr('disabled','disabled').text("Deleting...");
		jQuery.ajax({
			type: 'POST',
			url: jQuery('#del').attr('href'),
			data: { "_method" : jQuery('#del').data("method")  },
			success: function(data){window.location = '/admin/canned_responses/folders/';}
		});
	});
	jQuery('#delete-cancel').bind('click', function(){
		jQuery('#folder-delete').dialog('close');
	});

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
	jQuery('#del').attr('href', url);
	if(!jQuery('[data-folder='+folder_id+']').hasClass('default-folder'))
		jQuery('#edit-ca-folder, #del').show();
	jQuery('#move, #admin_canned_response_submit').attr('disabled', 'disabled');
	jQuery('#folder_edit_form').attr('action', url);
	jQuery('#can-menu').toggle();
	jQuery(".catch").css("font-weight","normal").find('.ticksymbol').remove();
	jQuery('.catch').removeClass('selected-folder');
	jQuery('[data-folder='+folder_id+']').css("font-weight","bold").prepend(ticksymbol).addClass('selected-folder');
	var tes = jQuery('[data-folder='+folder_id+']').text();
	jQuery("#menu-block").text(tes);
	jQuery('#admin_canned_responses_folder_name').val(jQuery('[data-folder='+folder_id+']').data('name'));
	if(jQuery('#responses-select-all').prop("checked"))
		jQuery('#responses-select-all').click();
}

jQuery(".default-folder").live('click', function(){
	jQuery('#edit-ca-folder, #del').hide();
});

jQuery('#folder_edit_form').bind('keyup', function(){
	if(jQuery('#folder_edit_form #name').val() != "")
		jQuery('#save_edit').removeAttr('disabled');
	else
		jQuery('#save_edit').attr('disabled', 'disabled');
});


makeFolderActive(folder_id);

jQuery('#can-menu').hide();
