define([
  'text!templates/chat/close/ticket_search.html',
  'views/chat/create_ticket'
], function(searchTemplate,createTicket){
  var $ = jQuery;
  var TicketSearchView = Backbone.View.extend({
        render:function(chat) {
            	 var that = this;
               require(['text!templates/chat/close/ticket_search_list.html'],function(template){
                  $('body').append(_.template(searchTemplate,{visitor_name:chat.visitor.name}));
                   var search_container = $('.' + 'chat_tkt_search_container' || "search_container")
                                           .freshTicketSearch({ className: 'chat_tkt_search_container',
                                                                template:  new Template(template)
                                                              });
                   that.initial_search();
                   that.listen(chat);
               });

       	},

        initial_search:function(){
          $('.chat_tkt_search_container').initializeRequester(CURRENT_USER.username);
        },

        listen:function(chat) {
            var that = this;
        	$('#go_back').on('click', function(){  
                $('#ticket_search_view').hide();
                $('#ticket_options').show();
          });

          $('.chat_tkt_search_container .autocompletepane ul').on('click', 'li' , function(){
                that.selected_ticket_id = $(this).find('.searchresult').attr('data-id');
                that.selected_ticket_subject = $(this).find('.item_info').html();
	              $('#ticket_search_view').hide();
	              $('#ticket_options,#return_select_tkt').show();
	              $('#confirm_tkt').removeClass("disabled");
	              $('#existing_tkt_link').remove();
	              $('#existing_tkt_subject').text( "Ticket:"+that.selected_ticket_subject );
        	});

        },

        selected_ticket:function() {
          return this.selected_ticket_id;
        }


  });
        return  (new TicketSearchView());
});