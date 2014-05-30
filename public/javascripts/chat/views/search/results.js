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
		count:0,
		render:function(data){
			if($("body").hasClass("ticket_list")){
				$("body").removeClass("ticket_list");
			}
			$("#search_results_expand").hide();
			$("#search_results_list").show();	 		
			$('#search_results_list').html('');
			this.count = data.count;
	 		this.add(data.results, data.msg, "start");
			this.paginate(data,1);
		},
		add:function(results, msgObj, type){
			var data="", id="", cnt=0, rlen=results.length;
			if(rlen == 0 && type == "start"){
				$("#search_results_list").html('<div class="emptymsg">'+i18n.nochat+'</div>');
			}
			for(var r=0; r<rlen; r++){
				cnt = 0;
				id = results[r].id;
				data = msgObj[id];
				if(data){
					var resDiv = $('<div>');
					resDiv.addClass("rsltgrp");

					var content = "";
					for(var k in data){
						if(data.hasOwnProperty(k)){
							if(cnt == 2){
								break;
							}
							var photo = data[k].photo;
							if(!photo){
								photo = "../../images/fillers/profile_blank_thumb.gif";
							}
							content += _.template(messageTemplate, {msg:data[k].msg, name:data[k].name, photo:photo});
							cnt++;
						}
					}

					var title = "";
					if(results[r].location){
						title = i18n.chat_with_loc;
						title = title.replace('$1',results[r].title).replace('$2',userCollection.get(results[r].userId).get('name')).replace('$3',results[r].location);
					}else{
						title = i18n.chat_with_noloc;
						title = title.replace('$1',results[r].title).replace('$2',userCollection.get(results[r].userId).get('name'));
					}

					var resObj = {title:title, time:new Date(results[r].updatedAt), cont:content};
					$('#search_results_list').append(resDiv.html(_.template(resultTemplate,{obj:resObj})));
					resDiv.on('click',function(id){
						return function(){
							chat_socket.emit('chat transcript',{
								id: id
							});
						}
					}(id));
				}
			}
		},
	 	paginate:function(data, page){
	 		var that = this;
	 		that.type = data.type;
			that.page = page;
			that.total = Math.ceil(that.count/that.limit);

			if(that.page<that.total){
				that.nextPage = that.page+1;
				var moreDiv = $('<div>');
				moreDiv.attr("id","search_results_more");
				moreDiv.addClass("chat_loadmore btn btn-secondary");
				$('#search_results_list').append(moreDiv.html(i18n.chat_loadmore));
				moreDiv.unbind('click').on('click',function(data){
					return function(){
						that.load(data);
					}
				}(data));
			}
		},
		update:function(data){
			$('#search_results_more').remove();
			this.type = data.type;
			if(this.nextPage <= this.total){this.nextPage = this.nextPage+1;}
			this.add(data.results, data.msg, 'page');
			this.paginate(data, data.page);
		},
		load:function(data){
			var that = this;
			var qry = {page:that.nextPage, limit:that.limit, type: that.type};
			if(that.type == 'advance'){
				var dat = $('#date-range-field span').text().split('-'),
					frm = $.trim(dat[0]),
					to = $.trim(dat[1]);
				qry['key'] = $("#search_input").val();
				qry['loc'] = $('#filterLoc').val();
				qry['frm'] = frm;
				qry['to'] = to;
				qry['tag'] = $('#filterTag').val();
				qry['agent'] = $("#agentList").val();
				chat_socket.emit('search filter', qry);
			}else{
				chat_socket.emit('search request', qry);
			}
		}
	});	

	if(!_view){_view = new ResultsView;}

	return _view;
});