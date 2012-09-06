var Helpdesk = Helpdesk || { };
Helpdesk.UnlockedQuests = (function(){
   var _FD = {
		_const:{
			'url': '/admin/gamification/active_quests',
			'content': '<div id="quest-container" class="panel-row">\
								<div class="floatl ">\
									<ul id="quest-badge-menu"><li class="##quest_badge##"></li>\
									<li class="dashboard-quest-points" style="">##quest_points##</li></ul></div>\
								<div id="quest-details-container" class="panel-content">\
					  				<h4>##quest_title##</h4>\
									<p class="help-text">##quest_desc##</p>\
								</div>\
							</div>'
		},

		makeAjaxRequest: function( args ){
            args.contentType = args.contentType ? args.contentType : 'application/json';
            args.type = args.type? args.type: "POST";
            args.url = args.url;
            args.dataType = args.dataType? args.dataType: "json";
            args.success = args.success? args.success: function(){};
            jQuery.ajax( args );
        }

   }

   return {
   		init: function(){
   			var args = {};
   			args.type = "GET";
   			args.url = _FD._const['url'];
   			args.dataType = "json";
   			args.success = function( response ) {
   				var _arr_content = "";
   				for(var i=0; i< response.length;i++){
   					var _content = _FD._const['content'];
   					_content = _content.replace('##quest_badge##',response[i]['quest']['award_data'][0]['badge']);
   					_content = _content.replace('##quest_points##',response[i]['quest']['award_data'][0]['point']);
   					_content = _content.replace('##quest_title##',response[i]['quest']['name']);
   					_content = _content.replace('##quest_desc##',response[i]['quest']['description']);
   					_arr_content += _content;
   				}
   				jQuery("#quests-container").html(_arr_content);
   			}
   			_FD.makeAjaxRequest(args);
   		}
   }
    
})();

jQuery(document).ready(function(){
		Helpdesk.UnlockedQuests.init();
});
