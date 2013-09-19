define([
  'views/daterange',
  'text!templates/search/results.html',
  'text!templates/search/message.html'
], function(daterangeView,resultTemplate,messageTemplate){
	var _view = null;
	var $ = jQuery;
	var ResultsView = Backbone.View.extend({
		limit:25,
		page:1,
		total:0,
		nextPage:2,
		type:'',
		render:function(data){
			if($("body").hasClass("ticket_list")){
				$("body").removeClass("ticket_list");
			}
			$('#search_results_list').html('');
	 		this.add(data.results, data.msg);
			this.paginate(data);
		},
		dateConversion:function(dat){
			var second=1000, minute=second*60, hour=minute*60, days=hour*24;
			var today = new Date();
			var date = new Date(dat);

			var day = $.datepicker.formatDate('MM dd, yy', date);
			var timeDiff = Math.abs(today.getTime() - date.getTime());
			var diffDays = Math.ceil(timeDiff / days);

			if(diffDays == 1){
				var day = "";
				var hrs = Math.floor(timeDiff / hour);
				var mins = Math.floor(timeDiff / minute);
				if(hrs > 0){
					day = hrs + " hours ";
				}
				if(mins % 60 > 0){
					day += (mins % 60) + " minutes";	
				}else{
					day += "now";
				}
			}
			return day;
		},
		add:function(results,msgObj){
			var data="",id="",cnt=0;
			var rlen=results.length;
			if(rlen==0){
				$("#search_results_list").html('<div class="emptymsg">'+i18n.nochat+'</div>');
			}
			for(var r=0; r<rlen; r++){
				cnt = 0;
				id = results[r].id;
				var resDiv = $('<div>');
				resDiv.addClass("rsltgrp");
				data = msgObj[id];
				var content = "";
				for(var k in data){
					if(data.hasOwnProperty(k)){
						if(cnt==2){
							break;
						}
						var time = new Date(data[k].time);
						var photo = data[k].photo;
						if(!photo){
							photo = "../../images/fillers/profile_blank_thumb.gif";
						}
						content += _.template(messageTemplate, {msg:data[k].msg, name:data[k].name, date:$.datepicker.formatDate("D, M dd 'at '",time)+time.toString("hh:mm tt"), photo:photo});
						cnt++;
					}
				}

				var day = this.dateConversion(results[r].updatedAt);
				var resObj = {agt:userCollection.get(results[r].userId).get('name'), par:results[r].title, loc:results[r].location, time:day, cont:content};
				$('#search_results_list').append(resDiv.html(_.template(resultTemplate,{obj:resObj})));
				resDiv.on('click',function(id){
					return function(){
						chat_socket.emit('chat transcript',{
							id: id
						});
					}
				}(id));
			}
		},
	 	paginate:function(data){
	 		var that = this;
	 		that.type = data.type;

			if(data.count<=that.limit){$(window).unbind('scroll');return;}
			that.page=1;
			that.total = Math.ceil(data.count/that.limit);
			if(that.page<that.total){that.nextPage=that.page+1;}

			$(window).scroll(function(){
				if($('#search_results_list').length==0 || !$('#search_results_list').is(":visible")){return;}
				if ( document.documentElement.clientHeight + $(document).scrollTop() >= document.body.offsetHeight ){
					if(that.page==that.total){
			    		$(window).unbind('scroll');
			    		return;
			    	}

			    	chat_socket.once('search paginate',function(data){
			    		that.type = data.type;
						that.page = data.page;
				 		if(that.nextPage<=that.total){that.nextPage=that.nextPage+1;}				 			
						that.add(data.results, data.msg);
					});

			    	var qry = {key:$("#search_input").val(), page:that.nextPage, limit:that.limit, type: that.type};
			    	if(that.type == 'advance'){
			    		var dat = $('#date-range-field span').text().split('-'),
	 						frm = $.trim(dat[0]),
	 						to = $.trim(dat[1]);
                  		qry['loc'] = $('#filterLoc').val();
                  		qry['frm'] = frm;
                  		qry['to'] = to;
                  		qry['tag'] = $('#filterTag').val();
                  		qry['agent'] = $("#agentList").val();
			    	}
					chat_socket.emit('search request',
				 		qry
				 	);
			 	}
			});			
		}
	});	

	if(!_view){_view = new ResultsView;}

	return _view;
});