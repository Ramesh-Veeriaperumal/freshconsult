  simpleTimedSearch("#searchbox", ca_responses_search_url, 2000);

  loadRecent();

  jQuery('<div id="cf_cache" class="hide"></div>').appendTo('body');

  jQuery('#searchbox').bind('keyup', function (ev) {
    if(ev.keyCode >= 46 && ev.keyCode <= 90 || ev.keyCode == 8)
    {
      jQuery('#clear-search').show();
  	  jQuery('#search-list').show();
    	jQuery('#fold-list').hide();
      jQuery('#search-list').empty().addClass('loading-center');
    }
  });

  jQuery(".item_info").live('click',function(){
    jQuery(".item_info").removeClass('folderSelected');
    var a = jQuery(this).data('folder');
    jQuery('[data-folder=' + a + ']').addClass('folderSelected');
  });

  if (jQuery('#fold-list .small-list-left').children().hasClass('list-noinfo'))
  {
    localStorage.removeItem('local_ca_response')
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
    if(jQuery(this).parents('#recently_used_list').length == 0)
      loadRecent();
  });

  function loadRecent()
  {
  	if(!localStorage["local_ca_response"])
  	{
  		jQuery('#recently_used_container').hide();
      jQuery('.back1, .pick-response, #clear-search, .pick-response-header, .small-list-right, .list2, .canned-icons').addClass('no_recently_used');
  	}
  	else
  	{
  		jQuery('#recently_used_list').empty().addClass('loading-center');
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
    jQuery('#responses').empty().addClass('loading-center');
  });

  jQuery('#canned_response_list a').first().click();