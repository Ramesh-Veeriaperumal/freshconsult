define([
], function(){
	var $ = jQuery;
	var TabView = Backbone.View.extend({
		el: '.container-fluid',
		render:function(fn){
			if(!($("#tabs-group li").length>0)){
				$( "#tabs" ).jtabs({
					closable:true,
					collapsible:true,
					add: function(e, ui){
						$('#tabs').jtabs('select', '#' + ui.panel.id);
					}
				});

				// fix the classes
				$( ".tabs-bottom .ui-tabs-nav, .tabs-bottom .ui-tabs-nav > *" )
					.removeClass( "ui-corner-all ui-corner-top" )
					.addClass( "ui-corner-bottom" );

				// move the nav to the bottom
				$( ".tabs-bottom .ui-tabs-nav" ).appendTo( ".tabs-bottom" );
			}
			fn();
		},
		title:function(id,value){
			var title = $('a[href="#tabs-chat-'+id+'"]');
			if(title){
				if(value.length>20){
					var newValue=value.substring(0,17)+"...";
					title.html("<span alt='"+value+"' title='"+value+"'>"+newValue+"</span>");
				}else{
					title.html("<span>"+value+"</span>");
				}
			}
		}
	});
	return new TabView();
});