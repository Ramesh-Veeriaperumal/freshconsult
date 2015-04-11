window.liveChat = window.liveChat || {};

"use strict";

liveChat.visitorListView = function(){
  return Backbone.View.extend({
    $loadMore : jQuery('<div>').attr("id",'load_more_visitors').addClass("chat_loadmore"),
    page      : 1,
    limit     : 15,
    events: {
      'click #load_more_visitors'  : 'loadMore',
      'click .visitor_chatnow'     : 'initiateChat'
    },
    initialize : function(options) {
      this.type = options.type;
      this.template = window.JST['livechat/templates/visitors/visitorList'];
      this.$el.attr({ id: 'visitor_results', class: 'visitor_results' });
      this.collection = options.collection;
      this.filteredCollection = options.filteredCollection;
      this.listenTo(this.collection, 'change:available', this.addVisitor);
      this.listenTo(this.collection, 'remove', this.removeVisitor);
      this.listenTo(this.collection, 'remove_visitor', this.removeVisitor);
      this.listenTo(this.collection, 'change_visitor_type', this.addVisitor); // when a visitor becomes active in collection
      this.listenTo(this.collection, 'save_filterd_visitors', this.saveFilteredCollection); //from visitor collection fetch
      this.listenTo(this.collection, 'change_count', this.setCount);
    },
    saveFilteredCollection : function(visitors){
      if(this.type == 'newVisitor'){
        visitors.values = jQuery.map(visitors.values,JSON.parse);
      }
      this.filteredCollection.add(visitors.values,{merge: true});
      this.filteredCollection.sort({silent: true});
      this.collection.saveCount(visitors.count);
      this.render();
    },
    render : function() {
      var html = [], that = this; 
      that.$el.appendTo('#visitor_results_container');
      that.filteredCollection.first(that.limit).each(function(visitor){
        html.push(that.template({visitor:that.parseVisitor(visitor.toJSON())}));
      });
      if(html.length > 0){
        var visitors_table = jQuery('<table>');
        that.$el.html('').append(visitors_table);
        visitors_table.append(html.join(''));
      }else{
        that.addEmptyMessage();
      }
      this.highlightCurrentType();
      this.removeLoader();
      this.addLoadMoreOption();
      this.setCount();
      return this;
    },
    parseVisitor : function(visitor){
      var sclass = { returnVisitor:'return-visitor', newVisitor:'new-visitor', inConversation:'chat-visitor' };
      if(visitor.location){
        if(!_.isString(visitor.location)){
          var location = CHAT_I18n.unknown;
          if(visitor.location.address){
            if(visitor.location.address.city){
              location = visitor.location.address.city+", ";
            }
            if(visitor.location.address.region){
              if(location == CHAT_I18n.unknown){
                location = "";
              }
              location += visitor.location.address.region+", ";
            }
            if(visitor.location.address.country){
              if(location == CHAT_I18n.unknown){
                location = "";
              }
              location += visitor.location.address.country;
            }
          }
          visitor.location = location;
        }
      }else{
        visitor.location = CHAT_I18n.unknown;
      }
      try{
        var useragent = JSON.parse(visitor.useragent);
      }catch(err){
        var useragent = visitor.useragent;
      }
      if(useragent){
        visitor.page = useragent.page;
        visitor.title = useragent.title;
      }else{
        if(visitor.current_session && visitor.current_session.url){
          visitor.page = visitor.current_session.url;
        }else{
          visitor.page = '';
        }
      }
      if(!visitor.title || visitor.title ==""){
        visitor.title = this.urlParser(visitor.page);
      }
      if(visitor.time){
        visitor.time = new Date(visitor.time).toISOString();
      }
      if(visitor.last_visited_at){
        visitor.time = new Date(visitor.last_visited_at).toISOString();
      }
      visitor.sclass = sclass[this.type];
      visitor.tip = (this.type == 'returnVisitor') ? CHAT_I18n.returning_visitor : CHAT_I18n.new_visitor;
      visitor.name = visitor.name? ((visitor.name.indexOf('visitor')==0)? "" : visitor.name) : "";
      if(!visitor.name){
        visitor.name = visitor.tip ;
      }
      return visitor;
    },
    setCount :function(){
      jQuery("#inConversationCount span").html(visitorCollection.count.inConversation);
      jQuery("#newVisitorCount span").html(visitorCollection.count.newVisitor);
      jQuery("#returnVisitorCount span").html(visitorCollection.count.returnVisitor);
    },
    addVisitor : function(visitor){
      if(visitor instanceof Backbone.Model){
        visitor = visitor.toJSON();
      }
      var that = this;
      var visitor_exists = this.filteredCollection.get(visitor.id);
      if(visitor.type == that.type && visitor.available){
        if(!visitor_exists || visitor.transfer){
          if(visitor.transfer){
            if(jQuery("#visitor_list_"+visitor.id).length>0){
              jQuery("#visitor_list_"+visitor.id).remove();
            }
          }
          this.filteredCollection.add(visitor,{merge: true});
          var $table = that.$el.find("table");
          if($table.length==0){
            $table = jQuery('<table>');
            that.$el.html('').append($table);
          }
          if(that.filteredCollection.length > that.page * that.limit){
            that.render();
          }else{
            that.$el.find("table").prepend(that.template({visitor:that.parseVisitor(visitor)}));
          }
        }
      }else if (visitor_exists) {
        that.removeVisitor(visitor_exists);
      }; 
    },
    removeVisitor : function(visitor){
      var visitor_id;
      if(visitor instanceof Backbone.Model){
        visitor_id = visitor.get('id');
      }else{
        visitor_id = visitor.id;
      }
      this.filteredCollection.remove(visitor_id);
      if(jQuery("#visitor_list_"+visitor_id).length>0){
        jQuery("#visitor_list_"+visitor_id).remove();
      }
      if(this.filteredCollection.length == 0 ){
        this.addEmptyMessage();
      }
    },
    addEmptyMessage : function (){
      var empty_msg = {
        returnVisitor:CHAT_I18n.no_return_visitors, 
        newVisitor:CHAT_I18n.no_visitors, 
        inConversation:CHAT_I18n.no_conversation
      };
      this.$el.html('').append('<div class="emptymsg">'+empty_msg[this.type]+'</div>');
    },
    addLoadMoreOption : function(){
      if(jQuery('#load_more_visitors')){
        jQuery('#load_more_visitors').remove();
      }
      if(this.filteredCollection.length > this.page * this.limit){
        this.$el.append(this.$loadMore.html(CHAT_I18n.chat_loadmore));
      }
    },
    loadMore : function(){
      var begin = this.page * this.limit;
      var end   = begin + this.limit;
      var html = [],that=this;
      this.page ++;
      _.each(that.filteredCollection.slice(begin,end), function (visitor){
          html.push(that.template({visitor:that.parseVisitor(visitor.toJSON())}));
      });
      this.$el.find("table").append(html.join(''));
      this.addLoadMoreOption();
    },
    urlParser: function (uri) {
      var splitRegExp = new RegExp(
            '^' +
                '(?:' +
                '([^:/?#.]+)' +                         // scheme - ignore special characters
                                                        // used by other URL parts such as :,
                                                        // ?, /, #, and .
                ':)?' +
                '(?://' +
                '(?:([^/?#]*)@)?' +                     // userInfo
                '([\\w\\d\\-\\u0100-\\uffff.%]*)' +     // domain - restrict to letters,
                                                        // digits, dashes, dots, percent
                                                        // escapes, and unicode characters.
                '(?::([0-9]+))?' +                      // port
                ')?' +
                '(([^?#]+))?' +                           // path
                '(?:\\?([^#]*))?' +                     // query
                '(?:#(.*))?' +                          // fragment
                '$');

      if(!uri || uri.length==0){
          return "";
      }
      var split = uri.match(splitRegExp);
      var path = (split[5])?split[5]:"";
      path = path.replace("\/","");
      if(path=="" && split[3]){
          return uri;
      }else{
          return split[5];
      }
    },
    highlightCurrentType:function(){
      jQuery("#visitor_filter > a > div.on").removeClass("on");
      jQuery("#"+this.type+"Count").find('div').addClass('on');
    },
    removeLoader : function (){
      jQuery("#loading-box").hide(); 
      jQuery("#visitors_view_container").css('opacity','1');
    },
    addLoader : function(){
      jQuery("#loading-box").show(); 
      jQuery("#visitors_view_container").css('opacity','0.2');
    },
    initiateChat : function(event){
      var clicked_row = jQuery(event.currentTarget);
      var visitor_data = {
        id : clicked_row.attr("data-id"),
        widget_id : clicked_row.attr("data-widget-id"),
        visitor_info : this.filteredCollection.get(clicked_row.attr("data-id")).toJSON(),
        fromlist : true,
        reopenChat: true
      };
      this.collection.acceptVisitor(visitor_data);
    }
  });
}