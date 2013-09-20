define([
  'text!templates/search/message.html'
], function(messageTemplate){
  var $ = jQuery;
  var TicketView = Backbone.View.extend({
        
        msgDateString:function(result) {
            var date = new Date(result.createdAt);
            var hours = date.getHours();
            var minutes = date.getMinutes();
            var am_pm = hours >= 12 ? 'pm' : 'am';
            hours = hours % 12;
            hours = hours ? hours : 12;
            minutes = minutes < 10 ? '0'+minutes : minutes;
            return (hours + ':' + minutes+am_pm);
        },

        request:function(url,params,chat) {
          var that = this;
            $.ajax({
                  type: "POST",
                  url: url,
                  dataType: 'json',
                  data: params,
                  success: function(response){
                    that.closeChatWindow(chat);
                    if(response.message){
                      that.notice(response.message);
                    }
                  },
                  error: function(response){
                    that.closeChatWindow(chat);
                    if(response.message){
                      that.notice(response.message);
                    }
                    else{
                      that.notice(i18n.error);
                    }
                  }
              });
          },

          notice:function(msg){
             $("#noticeajax").text(msg).show();
             closeableFlash('#noticeajax');
          },

        create:function(chat) {
            var that = this;
            if(!chat.existing_tkt_id){
              var created_date = new Date(chat.createdAt); 
              var visitor_name = (chat.visitor.name) ?  chat.visitor.name : chat.visitor.userName;
              var year = created_date.getFullYear()-2000;
              var month = created_date.getMonthName().slice(0,3);
              var day = created_date.getDayName().slice(0,3);
              var location = chat.location ? " ("+chat.location+") " : " "
              var subject = i18n.chat_with + " "+ visitor_name+" "+i18n.on_+" "+day+" "+created_date.getDate()+", "
                            +month+" '"+year;
              var tkt_desc = i18n.ticket_desc+"<b>"+visitor_name+"</b>"+location+i18n.and+" <b>"+
                             CURRENT_USER.username+"</b>"+"."+"<br>"+i18n.transcript_added_msg;
              var agent_email = userCollection.get(CURRENT_USER.id).get('email');
              var email = (chat.visitor.email) ? chat.visitor.email : agent_email;
            }
            var results = chat.messages;
            var conversation = "";
            for(var r=0; r<results.length; r++){
              var strTime = that.msgDateString(results[r]);
              resObj = _.template(messageTemplate, {msg:results[r].msg, name:results[r].name, date:strTime, 
                       photo:results[r].photo, cls: results[r].authType!="visitor" ? "conversation_user" : ""});
              conversation += resObj;
            }
            var ticket = { "email":email,"content":tkt_desc,"subject":subject};
            var note = "<div class = conversation_wrap>"+conversation+"</div>";

            var params,url;
              if(chat.existing_tkt_id){
                params = {"ticket_id":chat.existing_tkt_id,"note":note};
                url ="/chat/add_note";
                that.request(url,params,chat);
              }
              else{
                params = {"ticket":ticket,"note":note};
                url ="/chat/create_ticket";
                that.request(url,params,chat);
              }
          },

          closeChatWindow:function(chat){
              $("#ticket_options,#ticket_search_view").fadeOut('fast',function(){
                $("#chat_ticket_options").remove();
              });
              var triggerObj = $('li.ui-state-active').find('a:last-child');
              triggerObj.trigger('click');
              window.chatCollection.remove(chat);
              localStore.remove("chat",chat.id);
          }
  });
        return  (new TicketView());
});
