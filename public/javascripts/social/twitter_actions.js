var j = jQuery.noConflict();
// TWITTER ACTIONS IN CONVO PANEL
var TwitterActions = Class.create({
    initialize: function() {
        this.twitterBoxEle = {
            convo_panel: "#conv-panel",
            convo_wrapper: ".conv-wrapper",
            reply_btn: ".reply-btn",
            rt_btn: ".rt-btn",
            show_retweets: ".show-retweets",
        };
        this.viewPortHeight = j(document).height();
        this.registerCustEvent();
        j(document).on('mousewheel DOMMouseScroll', this.twitterBoxEle.convo_wrapper, function(ev) {
            if (ev.originalEvent) ev = ev.originalEvent;
            var delta = ev.wheelDelta || -ev.detail;
            this.scrollTop += (delta < 0 ? 1 : -1) * 10;
            ev.preventDefault();
        });
    },
    onConvoLoaded: function(e) {
        this.destroy();
        this.registerCustEvent();
        j(this.twitterBoxEle.convo_wrapper).css({
            "height": this.viewPortHeight - j(".tw-wrapper .pane-head").height() - 10 + "px"
        });
        //settings events for twitter convo
        j(this.twitterBoxEle.convo_panel).on('click.twitter_evt', this.twitterBoxEle.reply_btn, this.toggleReplyBox.bindAsEventListener(this)); //toggle Reply button
        j(this.twitterBoxEle.convo_panel).on("click.twitter_evt", this.twitterBoxEle.rt_btn, this.toggleRTbox.bindAsEventListener(this)); //toggle Retweet box
        j(this.twitterBoxEle.convo_panel).on("click.twitter_evt", this.twitterBoxEle.show_retweets, this.showRT.bindAsEventListener(this)); //show Retweets
        j(this.twitterBoxEle.convo_panel).on('click.twitter_evt', ".reply-submit", this.triggerReplySubmit.bindAsEventListener(this)); // trigger reply action to a tweet
        j(this.twitterBoxEle.convo_panel).on('click.twitter_evt', ".rt-submit", this.triggerRetweetSubmit.bindAsEventListener(this)); // trigger retweet action of a tweet
        j(this.twitterBoxEle.convo_panel).on('click.twitter_evt', ".oi-btn", this.toggleOtherInteractionBox.bindAsEventListener(this)); //toggle User Interaction box - to be TESTED
        j(this.twitterBoxEle.convo_panel).on('click.twitter_evt', '#backtoconv-btn', this.back2ConvoBox.bindAsEventListener(this)); // action on left arrow to go back to convobox from user
        j(this.twitterBoxEle.convo_panel).on('click.twitter_evt', ".show_more_interactions", this.viewUserInteraction.bindAsEventListener(this));
        j(this.twitterBoxEle.convo_panel).on('click.twitter_evt', 'a.current_interaction_ctt', this.currentInteractionClick.bindAsEventListener(this));
        j(this.twitterBoxEle.convo_panel).on('click.twitter_evt', 'a.unfav-twt', this.currentInteractionUnfav.bindAsEventListener(this));
        j(this.twitterBoxEle.convo_panel).on('click.twitter_evt', 'a.fav-twt', this.currentInteractionFav.bindAsEventListener(this));
        j(this.twitterBoxEle.convo_panel).on('click.twitter_evt', '.twt-follow', this.currentInteractionFollowers.bindAsEventListener(this));
        j(this.twitterBoxEle.convo_panel).on('click.twitter_evt', 'li.not-following', this.currentInteractionFollow.bindAsEventListener(this));
        j(this.twitterBoxEle.convo_panel).on('click.twitter_evt', 'li.following', this.currentInteractionUnFollow.bindAsEventListener(this));
        // -------- other actions in Convo Panel ---------
        j(this.twitterBoxEle.convo_panel).on("click.twitter_evt", "a.conv-userbtn", this.viewUserInteraction.bindAsEventListener(this));

        if (streamMgr.clicked_ele.rt) j(".current_feed").find(this.twitterBoxEle.rt_btn).trigger("click");
        else j(".current_feed").find(this.twitterBoxEle.reply_btn).trigger("click");
    },
    registerCustEvent: function(e) {
        j(document).on("convoLoadedEvent", this.onConvoLoaded.bindAsEventListener(this)); //Custom event - this will trigger on ajax call success
    },
    toggleReplyBox: function(e) {
        this._preventDefault(e);
        var feed_id = j(e.currentTarget).attr('data-feed-id'),
            textarea = j("#reply_text_area_" + feed_id),
            val = textarea.val();
        if (j("#reply_box_" + feed_id).is(":hidden")) {
            j(this.twitterBoxEle.convo_wrapper).find('.twt-box').hide();
            j("#reply_box_" + feed_id).slideDown();
        } else {
            j(this.twitterBoxEle.convo_wrapper).find('.twt-box').hide();
            j("#reply_box_" + feed_id).show();
        }
        var search_type = j('#social_meta_info #social_search_type').val();
        j("#conv_div_" + feed_id).find('#search_type').val(search_type);
    },
    toggleRTbox: function(e) { //works fine
        this._preventDefault(e);
        var feed_id = j(e.currentTarget).attr('data-feed-id');
        if (j("#rt_box_" + feed_id).is(":hidden")) {
            j(this.twitterBoxEle.convo_wrapper).find('.twt-box').hide();
            j("#rt_box_" + feed_id).slideDown();
        } else {
            j(this.twitterBoxEle.convo_wrapper).find('.twt-box').hide();
            j("#rt_box_" + feed_id).show();
        }
    },
    showRT: function(e) {
        this._preventDefault(e);
        var retweeted_id = j(e.currentTarget).attr('data-retweeted-id');
        j('#conv-floater').fadeOut(300);
        j('#retweet-floater').fadeIn();
        j('#retweet-floater').find('#changed_rt_header').hide();
        j('#retweet-floater').find('#default_rt_header').show();
        j('#retweet-info').addClass('sloading loading-block');
        j.ajax({
            url: '/social/twitter/retweets',
            data: {
                retweeted_id: retweeted_id
            },
            success: function() {
                j("#retweet-floater .conv-wrapper").css({
                    "height": j(document).height() - j(".tw-wrapper .pane-head").height() - 10 + "px"

                });
            }
        });
    },
    toggleOtherInteractionBox: function(e) {
        this._preventDefault(e);
        j(".oi-contents").slideToggle(100);
        j(".oi-btn i").toggleClass("ficon-caret-down ficon-caret-up");
    },
    back2ConvoBox: function() {
        j('#userinfo-floater, #retweet-floater').fadeOut(300);
        j('#stream_userinfo, #retweet-info').empty();
        j('#conv-floater').fadeIn();
    },
    triggerReplySubmit: function(e) {
        var feed_id = j(e.currentTarget).attr("data-feed-id");
        j(e.currentTarget).attr("disabled", "disabled");
        j.ajax({
            type: 'POST',
            url: '/social/twitter/reply',
            data: j('#reply_form_' + feed_id).serialize(),
            success: function() {
                j(e.currentTarget).removeAttr("disabled");
                streamMgr.isTextAreaChanged = false;
            }
        });
    },
    triggerRetweetSubmit: function(e) {
        var feed_id = j(e.currentTarget).attr("data-feed-id");
        j(e.currentTarget).attr("disabled", "disabled");
        j.ajax({
            type: 'POST',
            url: '/social/twitter/retweet',
            data: j('#retweet_form_' + feed_id).serialize(),
            success: function() {
                j(e.currentTarget).removeAttr("disabled");
            }
        });
    },
    currentInteractionClick: function(e) {
        var feed_id = j(e.currentTarget).attr("data-feed-id");
        j("[data-feed-id=" + feed_id + "] .convert_as_ticket").addClass("sloading loading-tiny loading-align");
        j("[data-feed-id=" + feed_id + "] .convert_as_ticket i").hide();
        var element = "#conv_div_";
        var params = {
            feed_id: feed_id,
            stream_id: j(element + feed_id + " #stream_id").val(),
            user_id: j(element + feed_id + " #user_id").val(),
            user_name: j(element + feed_id + " #user_name").val(),
            user_screen_name: j(element + feed_id + " #screen_name").val(),
            user_image: j(element + feed_id + " #img_url").val(),
            in_reply_to: j(element + feed_id + " #in_reply_to").val(),
            text: j(element + feed_id + " #twt_msg").val(),
            parent_feed_id: j(element + feed_id + " #parent_feed_id").val(),
            user_mentions: j(element + feed_id + " #user_mentions").val(),
            posted_time: j(element + feed_id + " #posted_time").val()
        };
        var social_search_type = j('#social_meta_info #social_search_type').val();
        j.ajax({
            type: 'POST',
            url: '/social/twitter/create_fd_item',
            data: {
                item: params,
                search_type: social_search_type
            },
            datatype: 'json',
            success: function(data) {}
        });
        e.preventDefault();
    },
    currentInteractionUnfav: function(e) {
        var feed_id = j(e.currentTarget).attr("data-feed-id");
        j("[data-feed-id=" + feed_id + "] .unfav").addClass("sloading loading-tiny loading-align");
        j("[data-feed-id=" + feed_id + "] .unfav i").css('opacity','0');
        var element = "#conv_div_";
        var params = {
            feed_id: feed_id,
            stream_id: j(element + feed_id + " #stream_id").val(),
            user_screen_name: j(element + feed_id + " #screen_name").val()
        };
        var social_search_type = j('#social_meta_info #social_search_type').val();
        j.ajax({
            type: 'POST',
            url: '/social/twitter/unfavorite',
            data: {
                item: params,
                search_type: social_search_type
            },
            datatype: 'json',
            success: function(data) {}
        });
        e.preventDefault();
    },
    currentInteractionFav: function(e) {
        var feed_id = j(e.currentTarget).attr("data-feed-id");
        j("[data-feed-id=" + feed_id + "] .fav").addClass("sloading loading-tiny loading-align");
        j("[data-feed-id=" + feed_id + "] .fav i").css('opacity','0');
        var element = "#conv_div_";
        var params = {
            feed_id: feed_id,
            stream_id: j(element + feed_id + " #stream_id").val(),
            user_screen_name: j(element + feed_id + " #screen_name").val()
        };
        var social_search_type = j('#social_meta_info #social_search_type').val();
        j.ajax({
            type: 'POST',
            url: '/social/twitter/favorite',
            data: {
                item: params,
                search_type: social_search_type
            },
            datatype: 'json',
            success: function(data) {}
        });
        e.preventDefault();
    },
    currentInteractionFollowers: function(e){
      j(".twt-follow ul").addClass('dropdown');
      if(j(".twt-follow .dropdown li").length != 0){
        return false;
      } 
      j(".twt-follow .dropdown").addClass("sloading loading-block");
      screen_name =  j("#tw-profile .tw-handle").text().trim();
          
      j.ajax({
          url: "/social/twitter/followers",
          data: {
              screen_name: screen_name
          },
          success: function() {}
      });
      e.preventDefault();
    },
    currentInteractionFollow: function(e){
      this._preventDefault(e);
      var screen_name = j(e.currentTarget).attr("data-screen-name");
      var params = {
        to_follow: j("#tw-profile .tw-handle").text().trim(), 
        screen_name: screen_name,
        search_type: j('#social_meta_info #social_search_type').val()
      }
      j("[data-screen-name=" + screen_name + "]").addClass("sloading loading-tiny");
      j("[data-screen-name=" + screen_name + "] a").css('opacity','0');
       j.ajax({
            type: 'POST',
            url: "/social/twitter/follow",
            data: {
                user: params
            },
            success: function() {}
        });
       e.preventDefault();
    },
    currentInteractionUnFollow: function(e){
      this._preventDefault(e);
      var screen_name =  j(e.currentTarget).attr("data-screen-name");
      var params = {
        to_follow: j("#tw-profile .tw-handle").text().trim(), 
        screen_name: screen_name, 
        search_type: j('#social_meta_info #social_search_type').val()
      }
      j("[data-screen-name=" + screen_name + "]").addClass("sloading loading-tiny");
      j("[data-screen-name=" + screen_name + "] a").css('opacity','0');
       j.ajax({
            type: 'POST',
            url: "/social/twitter/unfollow",
            data: {
                user: params
            },
            success: function() {}
        });
       e.preventDefault();
    },
    viewUserInteraction: function(e) {
        this._preventDefault(e);
        j("#stream_userinfo").empty();
        j("#stream_userinfo").addClass("sloading loading-block");
        var feed_id = j(e.currentTarget).attr("data-feed-id");
        var user = {
            "screen_name": j("#conv_div_" + feed_id + " #screen_name").val(),
            "name": j("#conv_div_" + feed_id + " #user_name").val(),
            "id": j("#conv_div_" + feed_id + " #user_id").val(),
            "klout_score": j("#conv_div_" + feed_id + " #klout_score").val(),
            "normal_img_url": j("#conv_div_" + feed_id + " #img_url").val()
        };
        var stream_ids = j("#social_meta_info #stream_ids").val();
        j("#conv-floater").fadeOut(300);
        j("#userinfo-floater").show();
        j.ajax({
            url: "/social/twitter/user_info",
            data: {
                user: user
            },
            success: function() {
                j("#userinfo-floater .conv-wrapper").css({
                    "height": j(document).height() - j(".tw-wrapper .pane-head").height() - 10 + "px"
                });
            }
        });
    },
    _preventDefault: function(e) {
        if (e.preventDefault) e.preventDefault();
        e.returnValue = false; // for IE 8 & below
    },
    destroy: function() {
        j(this.twitterBoxEle.convo_panel).off('.twitter_evt');
        j(document).off("convoLoadedEvent");
    }
});
var twitterActions = new TwitterActions();
