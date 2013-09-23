define([  
  'underscore',
  'backbone',  
  'text!templates/search/layout.html',   
   'views/search/filter',
   'views/search/results',
   'views/search/listing'
], function(_, Backbone,layoutTemplate,filterView,resultsView,listView){  
	var searchView = Backbone.View.extend({		
		render:function(data){
			if(data.type == 'normal'){
				$(".container-fluid").html(_.template(layoutTemplate));
				filterView.render();
			}
			resultsView.header(data);
			resultsView.render(data);
		},
		show:function(results){
			this.render(results);
		},
		transcript:function(msgs){
			listView.render(msgs);
		}
	});
	return 	(new searchView());
});