  simpleTimedSearch("#searchbox", ca_responses_search_url, 2000);

  loadRecent();

  jQuery('<div id="cf_cache" class="hide"></div>').appendTo('body');

  jQuery('#searchbox').bind('keyup', function (ev) {
    if(ev.keyCode >= 46 && ev.keyCode <= 90 || ev.keyCode == 8)
    {
      jQuery('#clear-search').show();
  	  jQuery('#search-list').show();
    	jQuery('#fold-list').hide();
      jQuery('#search-list').empty().append("<div class='sloading loading-align'></div>");
    }
  });

  jQuery(".item_info").live('click',function(){
    jQuery(".item_info").removeClass('folderSelected');
    var a = jQuery(this).data('folder');
    jQuery('[data-folder=' + a + ']').addClass('folderSelected');
  });

  if (jQuery('#fold-list .small-list-left').children().hasClass('list-noinfo'))
  {
    localStorage.removeItem('local_ca_response');
    jQuery('#response_dialog').addClass('no_folders');
  }

  jQuery('.folderSelected').live('click', function(ev){
  ev.preventDefault();
  });

	jQuery('[data-response]').live('click', function(ev){
	  ev.preventDefault();
	  var id = jQuery(this).data('response');
  	var recId = [];
  	if (!localStorage["local_ca_response"] ) 
  	{
	   	localStorage["local_ca_response"] = recId;
    }
    else
    {
      recId = jQuery.parseJSON('[' + localStorage["local_ca_response"] + ']')
	  }
	  for(var i = 0; i < recId.length;i++)
	  {
		  if(recId[i] == id)
		  {
			  recId.splice(i,1);
		  }
	  }
	  recId.reverse();
   	recId.push(id);   
   	recId.reverse(); 
   	if(recId.length >= 8)
   	{
   		recId.splice(8);
   	}
    localStorage["local_ca_response"]=recId.toString();
  });

  function loadRecent()
  {
  	if(!localStorage["local_ca_response"])
  	{
  		jQuery('#recently_used_container').hide();
  	}
  	else
  	{
      jQuery('#recently_used_container').show();
      jQuery('#response_dialog').removeClass('no_recently_used');
      jQuery('#recently_used_list').empty().addClass('sloading loading-small');
  		new Ajax.Request(ca_responses_recent_url+localStorage["local_ca_response"]+']', 
    		{
    			asynchronous: true,
					evalScripts: true,
					method: 'get'
    		});   
  	}
  }

  jQuery("#clear-search").bind('click', function(){
  	jQuery("#searchbox").val('');
  	jQuery('#search-list').hide();
	  jQuery('#fold-list').show();
	  jQuery(this).hide();
	});

  jQuery('[data-folder]').bind('click', function(){
    jQuery('#responses').empty().addClass('sloading loading-small');
  });

  jQuery('#canned_response_list a').first().click();