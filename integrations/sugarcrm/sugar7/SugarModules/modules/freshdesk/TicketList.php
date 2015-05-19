<?php

function getTickets($focus, $field, $value, $view) {
	return "
		<style type='text/css'>
			#fd_loading { text-align: center; display:none}
			#tmp_container { display:none}
			.settings_link { float:right; padding: 5px; width: 50px;}
		</style>
		<div id='fd_loading'><img id='fd_loading_img' src='custom/themes/freshdesk/loading.gif' /></div>
		<div id='fd_container'></div>
		<div id='tmp_container'></div>
		<script type='text/javascript'>

		fetchCallback = {
			success: function(data) {
				console.log(data);
                                alert(data.responseText);
				document.getElementById('tmp_container').innerHTML = data.responseText;
				document.getElementById('fd_container').innerHTML = document.getElementById('fd_datacontainer').innerHTML;
				document.getElementById('tmp_container').innerHTML = '';
				document.getElementById('fd_loading').style.display = 'none';
				document.getElementById('fd_container').style.display = 'block';
			},
			failure: function(data) {
				document.getElementById('fd_container').innerHTML = 'Failed to load tickets from Freshdesk';
				document.getElementById('fd_loading').style.display = 'none';
			},
		}

		fetchTickets = function(filter, page) {
			document.getElementById('fd_loading').style.display = 'block';
			document.getElementById('fd_container').style.display = 'none';
			if(typeof(filter)==='undefined') filter = 'all_tickets';
   			if(typeof(page)==='undefined') page = '1';

			connection = YAHOO.util.Connect.asyncRequest ('GET', construct_url(filter, page) , fetchCallback);
		};

		construct_url = function(filter,page) {
			var url = 'index.php?module=freshdesk&action=ticketlist';
			url += '&focus=" . $focus->object_name ."';
			url += '&rec=" . $focus->id . "';
			url += '&filter=' + filter;
			url += '&page=' + page;
			return url;
		};
		fetchTickets();
		</script>
	";
}
