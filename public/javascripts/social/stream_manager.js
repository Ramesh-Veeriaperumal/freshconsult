var j = jQuery.noConflict();
var StreamManager = Class.create({
    initialize: function() {
        this.convoElement = "#conv-panel", this.loadingClass = 'sloading loading-block loading-tiny';
        //for closing conversation wrapper upon clicking outside on body and other than twt-list-item object
        this.mouse_is_in = {
            convo_panel: false,
            list_item: false
        };
        this.clicked_ele = {
            reply: false,
            rt: false,
            reply_focus: false,
            same_feed: this.getFeedId()
        };
        this.twitterStreamLoadPref = {
            initial_call: 0,
            show_old: 1,
            fetch_new: 2
        };
        this.streamBoxElements = {
            list_item: ".twt-list-item",
            convo_wrapper: "#conv-wrapper",
            stream_template: "#streamTemplate",
            sharer: ".sharer",
            sharer_reply_button: ".sharer_reply_button",
            sharer_rt_button: ".sharer_retweet_button",
            convert_as_ticket: ".unified_view_ctt",
            favorite_tweet: ".favorite_twt",
            unfavorite_tweet: ".unfavorite_twt",
            ticket_link: ".tw-tkt-link",
            viewon_twitter: ".tw-link",
            toggle_btn: "#settings-btn",
            search_submit: "#search_social"
        };
        this.socialPage = {
            left_pane: ".tw-accs",
            center_pane: ".center-pane",
            social_wrapper: ".tw-wrapper"
        }
        this.isTextAreaChanged = false;
        this.timer = 60000;
        this.eObjToTrackClick; //remove this after TWIPSY removed
        j('#post_tweet_textarea').NobleCount('#tweet_counter');
        j('.twt-rply').livequery(function() {
            var feed_id = j(this).attr('data-feed-id');
            j('#reply_text_area_' + feed_id).NobleCount('#SendTweetCounter_' + feed_id);
        });
        j('.post-twt-submit').attr("disabled", "disabled");
        j(document).on("keyup", ".reply-input", function(e) {
            var _val = j(e.currentTarget).val(),
                _len = j(this).data("tweet-count");
            if ((_val == "") || (_len < 0)) {
                j('.twt-submit').attr("disabled", "disabled");
            } else {
                j('.twt-submit').removeAttr("disabled");
            }
        });
        if (j('#unifiedStreams').length > 0) {
            j(this.socialPage.left_pane).on("click.social_evt", "#unifiedStreams", this.unifiedStreams.bindAsEventListener(this));
            j('#unifiedStreams').trigger("click");
        } else this.registerStreamEvents();
        Fjax.current_page = 'social_stream';
        //this.autoStreamLoad =  setInterval(this.loadNewFeeds.bindAsEventListener(this), this.timer);
        this.registerCustEvent();
    },
    getFeedId: function() {
        j('.twt-rply').livequery(function() {
            var feed_id = j(this).attr('data-feed-id');
            return feed_id;
        });
    },
    onStreamLoaded: function(e) {
        var $this = this;
        this.destroy(); //remove events to re-register - as the stream loads automatically and dom updated often
        this.isTextAreaChanged = false;
        this.registerCustEvent();
        this.autoStreamLoad = setInterval(this.loadNewFeeds.bindAsEventListener(this), this.timer);
        this.registerStreamEvents();
        j(this.streamBoxElements.stream_template).menuSelector({
            activeClass: 'selected-tweet',
            onHoverActive: false,
            onClickActive: true,
            scrollInDocument: true,
            menuHoverIn: "div.twt-list-item",
            additionUpKeys: 74,
            additionDownKeys: 75,
            onClickCallback: function(element) {
                $this.showSocialConvo(element);
            }
        });
        j(this.streamBoxElements.stream_template).menuSelector('reset');
    },
    registerStreamEvents: function(e) {
        //LEFT PANE ACTIONS
        j("#streams").on("click.social_evt", "#unifiedStreams", this.unifiedStreams.bindAsEventListener(this));
        j("#streams").on("click.social_evt", ".item_info", this.streamsItemInfo.bindAsEventListener(this)); // Clicking an individual brand(saved) stream
        j("#customSearches").on("click.social_evt", ".item_info", this.customSearchesItemInfo.bindAsEventListener(this));
        j("#streamHighlight").on("click.social_evt", "a.new-tweets", this.streamHighlight.bindAsEventListener(this));
        /*CENTER PANE ACTIONS */
        j(this.streamBoxElements.search_submit)
              .on("keyup.social_evt", this.triggerSocialSearch.bindAsEventListener(this));
    
        j(this.streamBoxElements.search_submit)
                .on("click.social_evt", this.streamBoxElements.toggle_btn, this.toggleAdvSearchBox.bindAsEventListener(this)) // for adv search and settings
                .on("submit.social_evt", this.searchSocialTab.bindAsEventListener(this)); // search form submit
        // stream box actions at center pane
        j(this.streamBoxElements.stream_template).on("mouseenter.social_evt", this.streamBoxElements.list_item, this.streamBoxMouseOver.bindAsEventListener(this))
            .on("mouseleave.social_evt", this.streamBoxElements.list_item, this.streamBoxMouseLeave.bindAsEventListener(this))
            .on("click.social_evt", this.streamBoxElements.viewon_twitter, this.viewOnTwitter.bindAsEventListener(this));
        //sharer clicks
        j(this.streamBoxElements.sharer).on("click.social_evt", this.streamBoxElements.sharer_reply_button, this.sharerReplyClick.bindAsEventListener(this))
            .on("click.social_evt", this.streamBoxElements.sharer_rt_button, this.sharerRTClick.bindAsEventListener(this))
            .on('click.social_evt', this.streamBoxElements.convert_as_ticket, this.sharerConvertTkt.bindAsEventListener(this))
            .on('click.social_evt', this.streamBoxElements.favorite_tweet, this.sharerFavoriteTweet.bindAsEventListener(this))
            .on('click.social_evt', this.streamBoxElements.unfavorite_tweet, this.sharerUnfavoriteTweet.bindAsEventListener(this))
            .on('click.social_evt', this.streamBoxElements.ticket_link, this.ticketLink.bindAsEventListener(this));
        j("body").on("click.social_evt", "#show_more_feeds", this.showMoreFeeds.bindAsEventListener(this));
        /*Static RIGHT PANE ACTIONS */
        j("#recent_search").on("click.social_evt", "p.query-list a", this.recentSearchQL.bindAsEventListener(this));
        j(".tw-wrapper").on("click.social_evt", ".post-twt-submit", this.triggerPostTweetSubmit.bindAsEventListener(this))
            .on('click.social_evt', ".twt-as .dropdown-menu a", this.tweetAs.bindAsEventListener(this)); //tweet as user
        //convo panel actions
        j("body").on("mouseenter.social_evt", this.convoElement, this.convoBoxMouseOver.bindAsEventListener(this))
            .on("mouseleave.social_evt", this.convoElement, this.convoBoxMouseLeave.bindAsEventListener(this));
        j(this.convoElement).on("click.social_evt", ".conv-closebtn", this.closeSocialConvoBox.bindAsEventListener(this)); //action on close conversation
        j(this.streamBoxElements.stream_template).on("click.social_evt", "p.autolink a", this.onAutoLinkClick.bindAsEventListener(this));
        j('body').on("mouseup.social_evt", this.closeOnBodyClick.bindAsEventListener(this)); //on body click to close social convo box
        j(this.streamBoxElements.convo_wrapper).on("keyup.social_evt", ".reply-input", this.onReplyTextAreaChange.bindAsEventListener(this));
    },
    registerCustEvent: function(e) {
        j(document).on("streamLoadedEvent", this.onStreamLoaded.bindAsEventListener(this)); //Custom event - this will trigger on ajax call success
    },
    loadNewFeeds: function(e) {
        stream_type = jQuery("#social_meta_info #social_search_type").val();
        if (stream_type == "streams") {
            this.fetchStreamFeeds(this.twitterStreamLoadPref.fetch_new)
        } else if (stream_type == "live_search") {
            refresh_url = jQuery("#social_meta_info #refresh_url").val();
            if (refresh_url != "") {
                this.liveSearch(this.twitterStreamLoadPref.fetch_new);
            }
        } else if (stream_type == "custom_search") {
            refresh_url = jQuery("#social_meta_info #refresh_url").val();
            if (refresh_url != "") {
                this.customSearch(this.twitterStreamLoadPref.fetch_new);
            }
        }
    },
    onReplyTextAreaChange: function(e) {
        this.isTextAreaChanged = true;
    },
    triggerPostTweetSubmit: function(e) {
        j(e.currentTarget).attr("disabled", "disabled");
        j.ajax({
            type: 'POST',
            url: '/social/twitter/post_tweet',
            data: j('#post_tweet').serialize(),
            success: function() {
                j(e.currentTarget).removeAttr("disabled");
            }
        });
    },
    unifiedStreams: function(e) {
        j(this.streamBoxElements.stream_template).addClass(this.loadingClass + ' loading-align');
        this.applyChanges();
        var stream_ids = "",
            first_feed_id = "",
            last_feed_id = "";
        j("#streams li.strmlst").each(function() {
            stream_ids += j(this).find('.item_info').attr("data-stream-id") + ",";
            first_feed_id += "0,";
            last_feed_id += "0,";
        });
        stream_ids = stream_ids.slice(0, stream_ids.length - 1);
        first_feed_id = first_feed_id.slice(0, first_feed_id.length - 1);
        last_feed_id = last_feed_id.slice(0, last_feed_id.length - 1);
        j("#social_meta_info #social_search_type").val("streams");
        j("#social_meta_info #stream_ids").val(stream_ids);
        j('#social_meta_info #first_ids').val(first_feed_id);
        j('#social_meta_info #last_ids').val(last_feed_id);
        this.fetchStreamFeeds(this.twitterStreamLoadPref.initial_call);
        j('#streams li a').removeClass('active');
        j('#customSearches li a').removeClass('active');
        j(e.currentTarget).addClass('active');
        this._preventDefault(e);
    },
    streamsItemInfo: function(e) {
        /* Hide or show divs */
        this.applyChanges();
        /* change the search type to streams */
        j("#social_meta_info #social_search_type").val("streams");
        var current_stream_id = j(e.currentTarget).attr("data-stream-id");
        var stream_ids_array = [];
        stream_id = current_stream_id;
        params = {
            "stream_id": stream_id,
            "first_feed_id": 0,
            "last_feed_id": 0
        }
        this.getFeedsData(params, this.twitterStreamLoadPref.initial_call);
        j('#streams li a').removeClass('active');
        j('#customSearches li a').removeClass('active');
        j(e.currentTarget).addClass('active');
        this._preventDefault(e);
    },
    /* Show/hide dom when individual stream is clicked */
    applyChanges: function() {
        j(this.streamBoxElements.stream_template).addClass(this.loadingClass);
        j(".scl-search-here").hide();
        j(".no-stream").hide();
        /* Remove if any selected class in brand or custom streams */
        j('#customSearches li a').removeClass('active');
        j('#streams li a').removeClass('active');
        /* remove the highlight if its not clicked */
        j('#streamHighlight a.new-tweets').html(0);
        j('#streamHighlight').hide();
        j('#no_old_results').hide(); /* Hide the no-old results div */
        j("#advsearch-box").hide(); /* Hide advance search options box */
        j('#tweet_noresults').hide(); /* Hide no tweet results div */
        j('#stream_error_msgs').hide(); /* Hide any error msgs*/
        j("#more_stream_feeds").hide(); /* Empty current template */
        j("#social_meta_info #refresh_url").val(""); /* Reset refresh url */
        j("#social_meta_info #next_results").val(""); /* Reset next results */
        j(this.streamBoxElements.stream_template).empty();
        this.clearSearchInputs();
    },
    /* Function for clearing the inputs when live search is made */
    clearSearchInputs: function() {
        j("#search_social #twitterquery").select2('val', []);
        j("#search_social #ignore-handles").select2('val', []);
        j("#search_social #ignore-keywords").select2('val', []);
        j('#no_query').hide();
    },
    getFeedsData: function(params, action) {
        var action_url = "";
        if (action == this.twitterStreamLoadPref.initial_call) action_url = "/social/streams/stream_feeds"
        else if (action == this.twitterStreamLoadPref.show_old) action_url = "/social/streams/show_old"
        else if (action == this.twitterStreamLoadPref.fetch_new) action_url = "/social/streams/fetch_new"
        j.ajax({
            url: action_url,
            data: {
                social_streams: params
            },
            success: function() {
                j.event.trigger({ //IMPORTANT TO REGISTER EVENTS AFTER STREAMS LOADED -  DOING IT with Custom Event
                    type: "streamLoadedEvent",
                    message: "Success",
                    time: new Date()
                });
                //j('#no_old_results').hide();
            }
        });
    },
    toggleAdvSearchBox: function(e) { //method for collapse/expand twitter search
        this._preventDefault(e);
        j("#advsearch-box").slideToggle(); // to be changed to css transition
    },
    triggerSocialSearch: function(e){
      if(e.keyCode == 13){
        j(this.streamBoxElements.search_submit).trigger('submit');
      }
    },
    searchSocialTab: function() {
        if (j("#twitterquery").val() == "") {
            j("#no_query").show();
            return false;
        }
        j(".scl-search-here").hide();
        j(".no-stream").hide();
        /* remove the highlight if its not clicked - i.e - newer feeds */
        j("#streamHighlight a.new-tweets").html(0);
        j("#streamHighlight").hide();
        /* Empty the current div */
        j(this.streamBoxElements.stream_template).empty().addClass(this.loadingClass);
        j("#more_stream_feeds").hide();
        j("#no_old_results").hide(); /* Hide the no-more results div */
        j("#tweet_noresults").hide(); /* Hide no tweet results div */
        j("#stream_error_msgs").hide(); /* Hide any error msgs */
        j("#social_meta_info #refresh_url").val(""); /* Reset refresh url */
        j("#social_meta_info #next_results").val(""); /* Reset next results */
        j("#no_query").hide(); /* Hide the no query entered if its shown*/
        j("#social_meta_info #social_search_type").val("live_search");
        this.liveSearch(this.twitterStreamLoadPref.initial_call, "live_search");
        return false;
    },
    /* Function for triggering the live twitter search */
    liveSearch: function(action, search_type) {
        var queries = j("#twitterquery").select2("val"),
            exclude_keywords = j("#ignore-keywords").select2("val"),
            exclude_handles = j("#ignore-handles").select2("val");
        var search_query_hash = {
            'q': queries,
            'exclude_handles': exclude_handles,
            'exclude_keywords': exclude_keywords,
            'type': search_type
        }
        this.searchTwitter(search_query_hash, action);
        return false;
    },
    /* Helper functions for triggering the ajax call for live & custom searches  - starts here */
    searchTwitter: function(search_query_hash, action) {
        next_results = j("#social_meta_info #next_results").val();
        refresh_url = j("#social_meta_info #refresh_url").val();
        search_query_hash['next_results'] = next_results
        search_query_hash['refresh_url'] = refresh_url
        this.getLiveFeedData(search_query_hash, action)
    },
    getLiveFeedData: function(search_query_hash, action) {
        var action_url = "";
        if (action == this.twitterStreamLoadPref.initial_call) action_url = "/social/twitter/twitter_search"
        else if (action == this.twitterStreamLoadPref.fetch_new) action_url = "/social/twitter/fetch_new" + search_query_hash.refresh_url
        else if (action == this.twitterStreamLoadPref.show_old) action_url = "/social/twitter/show_old" + search_query_hash.next_results
        j.ajax({
            url: action_url,
            data: {
                'search': search_query_hash,
            },
            success: function() {
                j.event.trigger({
                    type: "streamLoadedEvent",
                    message: "Success",
                    time: new Date()
                }); //IMPORTANT TO REGISTER EVENTS AFTER STREAMS LOADED -  DOING IT with Custom Event
            }
        });
    },
    customSearchesItemInfo: function(e) {
        this.applyChanges(); /* Hide or show divs */
        /* Remove if any selected class*/
        // j("#customSearches .item_info").each(function(el){
        //   j(el).removeClass('selected');
        // });
        j("#customSearches .item_info").removeClass("selected");
        /* change the stream type to custom_search */
        j("#social_meta_info #social_search_type").val("custom_search");
        j(e.currentTarget).addClass('selected');
        var keywords = j(e.currentTarget).attr("data-exclude-keywords"),
            handles = j(e.currentTarget).attr("data-exclude-handles"),
            queries = j(e.currentTarget).attr("data-query"),
            stream_id = j(e.currentTarget).attr("data-stream-id"),
            twitter_query = j("#search_social #twitterquery"),
            ignore_handles = j("#search_social #ignore-handles"),
            ignore_keywords = j("#search_social #ignore-keywords");
        var search_hash = {
            'q': queries.split(","),
            'exclude_handles': handles.split(","),
            'exclude_keywords': keywords.split(","),
            'stream_id': stream_id,
            'type': "custom_search"
        }
        twitter_query.select2('val', search_hash['q']);
        ignore_handles.select2('val', search_hash['exclude_handles']);
        ignore_keywords.select2('val', search_hash['exclude_keywords']);
        if ((ignore_keywords.select2('val') == "") && (ignore_handles.select2('val') == ""))
            j("#advsearch-box").slideUp();
        else
            this.toggleAdvSearchBox(e);
        this.searchTwitter(search_hash, this.twitterStreamLoadPref.initial_call);

        j('#customSearches li a').removeClass('active');
        j('#streams li a').removeClass('active');
        j(e.currentTarget).addClass('active');
        this._preventDefault(e);
    },
    streamHighlight: function(e) {
        j('#streamHighlight a.new-tweets').html('0');
        j('#streamHighlight').hide();
        j('#streamTemplate .refresh-item').show().removeClass('refresh-item');
        j("#streamTemplate").menuSelector("setFirstSelector");
        this._preventDefault(e);
    },
    recentSearchQL: function(e) {
        var twitter_query = j("#search_social #twitterquery"),
            ignore_handles = j("#search_social #ignore-handles"),
            ignore_keywords = j("#search_social #ignore-keywords");
        /* Hide the no-more results div */
        j('#no_old_results').hide();
        this.clearSearchInputs();

        query = j(e.currentTarget).attr('data-query').split(',');
        twitter_query.select2('val', query);

        handle = j(e.currentTarget).attr('data-exclude-handles').split(',');
        ignore_handles.select2('val', handle);

        keyword = j(e.currentTarget).attr('data-exclude-keywords').split(',');
        ignore_keywords.select2('val', keyword);
        if ((ignore_keywords.select2('val') == "") && (ignore_handles.select2('val') == ""))
            j("#advsearch-box").slideUp();
        else
            this.toggleAdvSearchBox(e);
        /* remove the active class on the streams and custom searches */
        j('#customSearches li a').removeClass('active');
        j('#streams li a').removeClass('active');
        j(this.streamBoxElements.search_submit).trigger('submit');
        this._preventDefault(e);
    },
    constructParams: function(feed_id, element) { //required for invokeConversation method
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
        return params;
    },
    /* Functions for triggering the unified feeds view(saved streams) - starts here */
    fetchStreamFeeds: function(action) {
        stream_ids = j("#social_meta_info #stream_ids").val();
        first_ids = j("#social_meta_info #first_ids").val();
        last_ids = j("#social_meta_info #last_ids").val();
        params = {
            "stream_id": stream_ids,
            "first_feed_id": first_ids,
            "last_feed_id": last_ids
        }
        this.getFeedsData(params, action)
    },
    /* Function for triggering the custom stream feeds view */
    customSearch: function(action) {
        var queries = j("#customSearches .item_info.selected").attr("data-query"),
            keywords = j("#customSearches .item_info.selected").attr("data-exclude-keywords"),
            stream_id = j("#customSearches .item_info.selected").attr("data-stream-id"),
            handles = j("#customSearches .item_info.selected").attr("data-exclude-handles");
        search_hash = {
            'q': queries.split(","),
            'exclude_handles': handles.split(","),
            'exclude_keywords': keywords.split(","),
            'stream_id': stream_id,
            'type': "custom_search"
        }
        this.searchTwitter(search_hash, action);
    },
    /*Stream Box Actions */
    streamBoxMouseOver: function(e) {
        this.mouse_is_in.list_item = true;
    },
    streamBoxMouseLeave: function(e) {
        this.mouse_is_in.list_item = false;
    },
    sharerReplyClick: function(e) {
        this.clicked_ele.reply = true;
        this.clicked_ele.rt = false;
        this.clicked_ele.reply_focus = true;
        this._preventDefault(e);
    },
    sharerRTClick: function(e) {
        this.clicked_ele.reply = false;
        this.clicked_ele.rt = true;
        this._preventDefault(e);
    },
    sharerConvertTkt: function(e) { //convert tweet as ticket
        e.preventDefault();
        e.stopPropagation();
        var feed_id = j(e.currentTarget).attr("data-feed-id");
        j("[data-feed-id=" + feed_id + "] .convert_as_ticket").addClass("sloading loading-tiny loading-align");
        j("[data-feed-id=" + feed_id + "] .convert_as_ticket i").css("opacity", "0");
        this.createFdItem(feed_id, "#tweet_div_");
    },
    sharerFavoriteTweet: function(e) { 
        e.preventDefault();
        e.stopPropagation();
        var feed_id = j(e.currentTarget).attr("data-feed-id");
        j("[data-feed-id=" + feed_id + "] .favorite_twt").addClass("sloading loading-tiny loading-align");
        j("[data-feed-id=" + feed_id + "] .favorite_twt i").css("opacity", "0");
        this.favoriteTweet(feed_id, "#tweet_div_");
    },
    sharerUnfavoriteTweet: function(e) {
        e.preventDefault();
        e.stopPropagation();
        var feed_id = j(e.currentTarget).attr("data-feed-id");
        j("[data-feed-id=" + feed_id + "] .unfavorite_twt").addClass("sloading loading-tiny loading-align");
        j("[data-feed-id=" + feed_id + "] .unfavorite_twt i").css("opacity", "0");
        this.unfavoriteTweet(feed_id, "#tweet_div_");
    },
    viewOnTwitter: function(e) {
        e.stopPropagation();
    },
    createFdItem: function(feed_id, element) {
        var params = this.constructParams(feed_id, element);
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
    },
    favoriteTweet: function(feed_id, element) {
        var params = this.constructParams(feed_id, element);
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
    },
    unfavoriteTweet: function(feed_id, element) {
        var params = this.constructParams(feed_id, element);
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
    },
    ticketLink: function(e) {
        e.stopPropagation();
    },
    onAutoLinkClick: function(e) {
        e.stopPropagation();
    },
    showMoreFeeds: function(e) {
        j("#show_more_feeds").hide();
        j("#more_stream_feeds").addClass(this.loadingClass);
        stream_type = j("#social_meta_info #social_search_type").val();
        if (stream_type == "streams") {
            this.fetchStreamFeeds(this.twitterStreamLoadPref.show_old);
        } else if (stream_type == "live_search") {
            this.liveSearch(this.twitterStreamLoadPref.show_old);
        } else if (stream_type == "custom_search") {
            this.customSearch(this.twitterStreamLoadPref.show_old)
        }
        this._preventDefault(e);
    },
    /* Convo Box Actions */
    convoBoxMouseOver: function() {
        this.mouse_is_in.convo_panel = true;
    },
    convoBoxMouseLeave: function() {
        this.mouse_is_in.convo_panel = false;
    },
    /* FIXED RIGHT PANE ACTIONS */
    showSocialConvo: function(that) { //callback works with menuselector plugin- DO NOT REMOVE
        this.eObjToTrackClick = null;
        j(this.streamBoxElements.list_item).removeClass("active");
        j(that).addClass("active");
        j(this.socialPage.left_pane).removeClass("light-up").addClass("light-dim");
        j(this.socialPage.center_pane).addClass("convo-up");
        var feed_id = j(that).attr("data-feed-id");
        if (j(this.convoElement).is(":visible")) {
            if (this.clicked_ele.same_feed == feed_id) {
                this.closeSocialConvoBox();
            } else {
                this.clicked_ele.same_feed = feed_id;
                this.showConvoSettings(feed_id);
            }
        } else {
            this.clicked_ele.same_feed = feed_id;
            this.showConvoSettings(feed_id);
        }
    },
    showConvoSettings: function(feed_id) {
        j(this.convoElement).css({
            'width': '40%',
            'position': 'fixed',
            'top': '0'
        });
        j(this.convoElement).addClass('navFromRightBounceIn').show();
        this.invokeConversation(feed_id, true, false);
        j("#conv-wrapper").empty();
        j('.wrapper .top_nav').css({
            'z-index': '0'
        });
        j("#userinfo-floater, #retweet-floater").hide();
        j("#userinfo-floater").fadeOut(300);
        j("#conv-floater").fadeIn();
        j("#retweet-floater").hide();
        j("#retweet-floater").find("#changed_rt_header").hide();
        j("#retweet-floater").find("#default_rt_header").show();
        j("#retweet-info").empty();
    },
    invokeConversation: function(feed_id, reply_clicked, retweet_clicked) {
        j("#conv-wrapper").addClass(this.loadingClass);
        var params = this.constructParams(feed_id, "#tweet_div_"),
            social_search_type = j("#social_meta_info #social_search_type").val(),
            $this = this;
        j.ajax({
            url: "/social/streams/interactions",
            data: {
                social_streams: params,
                search_type: social_search_type,
                is_reply: reply_clicked,
                is_retweet: retweet_clicked
            },
            success: function() {
                var textarea = j("#reply_text_area_" + feed_id),
                    val = textarea.val();
                j.event.trigger({
                    type: "convoLoadedEvent",
                    message: "Success",
                    time: new Date()
                });
                if ($this.clicked_ele.reply) {
                    textarea.focus();
                    textarea.val(val + " ");
                    $this.clicked_ele.reply = false;
                    $this.clicked_ele.reply_focus = false;
                }
                if ($this.clicked_ele.rt) {
                    $this.clicked_ele.rt = false;
                }
            }
        });
    },
    /*Right Pane Actions */
    tweetAs: function(e) {
        var str = "",
            handle_id, _img, _class;
        j(e.target).addClass('selected');
        _img = j(e.target).attr("data-img-url");
        handle_id = j(e.target).attr("data-handle-id");
        _class = j(e.target).attr("data-class");
        str = j(e.target).text();

        j('a.'+_class).html(str + " <i class='ficon-caret-down fsize-16' size='16'></i>").attr("data-original-title", str);
        
        j('.' + _class + ' img').attr("src", _img);
        j("input."+_class).val(handle_id);
    },
    closeOnBodyClick: function(e) {
        this.eObjToTrackClick = e.target; //remove after TWIPSY removed
        if (!this.mouse_is_in.convo_panel && !this.mouse_is_in.list_item) this.closeSocialConvoBox();
    },
    closeSocialConvoBox: function() {
        if (!j(this.convoElement).is(":hidden")) {
            if (!j(this.eObjToTrackClick).hasClass("fsize-18")) { //remove this line after TWIPSY removed
                this.closeConvo();
            }
        }
    },
    closeConvo: function() {
        var textarea = j("#reply_text_area_" + this.clicked_ele.same_feed),
            val = textarea.val();
        if (this.clicked_ele.reply) {
            textarea.focus();
            textarea.val(val + " ");
            this.clicked_ele.reply = false;
            this.clicked_ele.reply_focus = false;
        } else {
            j("#userinfo-floater, #retweet-floater").hide();
            j(this.streamBoxElements.convo_wrapper).empty();
            j("#stream_userinfo, #retweet-info").empty();
            j(this.convoElement).hide();
            this.isTextAreaChanged = false;
            j(this.streamBoxElements.list_item).removeClass("active");
            j(this.socialPage.left_pane).removeClass("light-dim").addClass("light-up");
            j(this.socialPage.center_pane).removeClass("convo-up");
        }
    },
    _preventDefault: function(e) {
        if (e.preventDefault) e.preventDefault();
        e.returnValue = false; // for IE 8 & below
    },
    destroy: function() {
        j('document, body, #streams, #customSearches, #streamHighlight, #search_social, .sharer, #streamTemplate, #recent_search, .tw-wrapper, #conv-panel').off('.social_evt');
        j(document).off("streamLoadedEvent");
        clearInterval(this.autoStreamLoad);

        //j('document, body').off('.social_evt');
        //j(this.socialPage.social_wrapper, this.socialPage.left_pane).off('.social_evt');
        //j(this.streamBoxElements.search_submit).off(".social_evt");
    }
});
var streamMgr = new StreamManager();
