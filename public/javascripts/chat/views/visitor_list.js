define([
  'collections/visitors',
  'views/url_parser',
  'text!templates/visitor_list.html',
  'text!templates/empty_list.html',
  'text!templates/visitor_layout.html'
], function(visitorCollection,urlParser,visitorTemplate,emptyTemplate,visitorLayout){
	var $ = jQuery;
	var visitorList = Backbone.View.extend({
		save:function(data){
	 		var values = data.values;
  
	 		if(!this.visitorCollection){
				this.visitorCollection = new visitorCollection();
			}

			for(var k in values){
				var details = JSON.parse(values[k]);
				details.id = k;
				visitors = this.visitorCollection.addNew(details);
			}
			if(data.type == "agent" || data.type == "return" || data.type == "online"){
				this.render(data.type);
			}
			this.setCount();
	 	},
	 	setCount:function(){
			var return_count = this.visitorCollection.count('return'),
				chat_count = this.visitorCollection.count('agent');
			var online_count = 0;
			if(this.visitorCollection){
				online_count = this.visitorCollection.length;
			}

			$("#chat_visitors_count, #pop_chat_count, #visitors_chat_count span").html(chat_count);
			$("#online_visitors_count, #bar_chats_count, #pop_online_count, #visitors_online_count span").html(online_count);
			$("#return_visitors_count, #pop_return_count, #visitors_return_count span").html(return_count);
	 	},
		render:function(type){
			if($("body").hasClass("ticket_list")){
				$("body").removeClass("ticket_list");
			}
			$("#Pagearea").html(_.template(visitorLayout,{}));
			if(this.visitorCollection && this.visitorCollection.length > 0){
				this.layout(type);
			}else{
				this.selectedItem(type);
				$("#visitor_results").html(_.template(emptyTemplate));
			}
			this.listen();
			this.setCount();
		},
		layout:function(type){
			var that = this,row=0;
			var visitors = this.visitorCollection.models;
			this.selectedItem(type);
			if(type!="online"){
				visitors = this.visitorCollection.getVisitors(type);
			}
			if(visitors.length==0){
				var errMsg = i18n.no_visitors;
				if(type=="agent"){
					errMsg = i18n.no_conversation;
				}else if(type=="return"){
					errMsg = i18n.no_return_visitors;
				}
				$("#visitor_results").html('<div class="emptymsg">'+errMsg+'</div>');
				return;
			}
			var table = $('<table>');
			$("#visitor_results").html('').append(table);
			_.each(visitors, function(visitor){
				var id = visitor.get('id');
				var rowClass = (row%2==0)?"even":"odd";
				var location = i18n.unknown;
				var session = visitor.get('current_session');
				var page="";

				if(session && session.url){
					page = session.url;
				}
				var geoLoc = visitor.get('location');
				if(geoLoc){
					if(geoLoc.address){
						if(geoLoc.address.city){
							location = geoLoc.address.city+", ";
						}
						if(geoLoc.address.region){
							if(location == i18n.unknown){
								location = "";
							}
							location += geoLoc.address.region+", ";
						}
						if(geoLoc.address.country){
							if(location == i18n.unknown){
								location = "";
							}
							location += geoLoc.address.country;
						}
					}
				}
				var details={id:id, class:rowClass, loc:location, page:page};
				
				var sclass = visitor.get('sclass');
				if(sclass == undefined){
					sclass = "new-visitor";
				}
				details.sclass = sclass;

				var message = i18n.new_visitor;
				if(visitor.get("return")!=undefined){
					message = i18n.returning_visitor;
				}
				if(visitor.get("agent")!=undefined){
					message = i18n.chatting_with+" "+userCollection.get(visitor.get("agent")).get('name');
				}
				details.message = message;
				details.name = visitor.get('name') ? visitor.get('name') : id;
				
				table.append(_.template(visitorTemplate, {visitor: details}));
				that.acceptVisitor(id);
			});
		},
		selectedItem:function(type){
			if(type=="agent"){
				$("#visitors_chat_count div").eq(0).addClass('on');
			}else if(type=="return"){
				$("#visitors_return_count div").eq(0).addClass('on');
			}else{
				$("#visitors_online_count div").eq(0).addClass('on');
			}
		},
		listen:function(){
			var sidebarView = require('views/sidebar');
			$("#web_chat_archive").on('click', function(e){
	 			sidebarView.showDetails(e,'archive');
	 		});
			$("#visitors_chat_count").on('click', function(e){
				sidebarView.showDetails(e,'agent');
			});
			$("#visitors_online_count").on('click', function(e){
				sidebarView.showDetails(e,'online');
			});
			$("#visitors_return_count").on('click', function(e){
				sidebarView.showDetails(e,'return');
			});
		},
		acceptVisitor:function(name){
			$("#"+name+"_link").on('click',function(){
				chat_socket.emit('accept visitor',{userid:name, name:name});
			});
		},
		fetch:function(type){
			var that = this;
			chat_socket.on('visitors online',function(data){
				that.save(data);
			});
			chat_socket.emit('visitors online',{
			   siteId: SITE_ID,
			   type: type
			});
		},
		newVisitor:function(data){
			this.save(data);

			var path = window.location.pathname;
			var paths = path.split("/");
			var loc = paths[paths.length-1];
			var values = data.values;
			for(var k in values){
				var details = JSON.parse(values[k]);
				if(loc=="return" && details.return){
					this.layout('return');
				}else if(loc=="agent" && details.agent){
					this.layout('agent');
				}else if(loc=="online"){
					this.layout('online');
				}
			}
		},
		removeVisitor:function(data){
			var id = data.id;
			if($("#visitor_list_"+id).length>0){
				$("#visitor_list_"+id).remove();
			}
			if(this.visitorCollection){
				this.visitorCollection.deleteVisitor(id);
				this.setCount();
			}
		},
		changeVisitor:function(data){
			this.visitorCollection.modify(data);

			var path = window.location.pathname;
			var paths = path.split("/");
			var loc = paths[paths.length-1];
			if(loc=="return" || loc=="agent" || loc=="online"){
				this.render(loc);
			}else{
				this.setCount();
			}
		},
		accept:function(data){
			this.changeVisitor({id: data.userName, agent: data.userId});
		}
	});
	return 	(new visitorList());
});