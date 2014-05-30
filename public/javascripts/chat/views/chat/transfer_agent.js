define([
  'text!templates/chat/transfer/layout.html',
  'text!templates/chat/transfer/agent.html'
], function(layout,agent){	
	var $ = jQuery;
	var transferView = Backbone.View.extend({
		isOpen: false,
		render:function(chat){	
			var that = this;
			if(!that.isOpen){
				that.isOpen = true;
				$('body').append(_.template(layout));
				that.agents(userCollection.models);
				$('.closeDialog, .cancelBtn').on('click', function(){
					that.isOpen = false;
					$('#transfer-agent').remove();
				});
				$('.saveBtn').on('click', function(){
					var userId = $('input[name="agent"]:checked').val();
					if(chat.transfer && chat.transfer>0){
						return;
					}
					if(userId){
						chat_socket.emit('transfer request',{chatId:chat.id,userId:userId});
						that.isOpen = false;
						$('#transfer-agent').remove();
						chat.transfer = userId;
					}
				});
				$('.agent-search').on('keyup',function(){
					  that.search(this.value);
				});
			}
		},
		agents:function(users,filter){
			var count=0;
			$('div.agent-scroll').html('');
			filter = (filter)?new RegExp(filter,'i'):false;
			_.each(users,function(user){
				if(CURRENT_USER.id != user.get('id') && user.get('status')==1 && (!filter || (filter.test(user.get('name'))))){	
					count++;
					var agentClass = (count%2==0)? "even" : "odd";
					$('div.agent-scroll').append(_.template(agent,{user:user,agentClass:agentClass}));
				}
			});
			if(count==0){
				$('div.agent-scroll').html('<div class="emptymsg">No agent available</div>');	
			}
		},
		search:function(filter){
		  this.agents(userCollection.models,filter);
		}
	});
	return 	(new transferView());
});