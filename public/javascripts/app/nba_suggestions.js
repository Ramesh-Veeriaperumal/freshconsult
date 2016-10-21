
window.App = window.App || {};
window.App.Tickets = window.App.Tickets || {};

(function($) {
    App.Tickets.NBA = {
        similar_tickets: [],
        removed_cards: [],
        widget_pos: 1,
        cardCount: 0,
        removedCards: 0,
        isFirstRes: true,
        sas_ids: "Ticket Id's = ",


        init: function(e) {
        if(nba.enable == "true"){
            $("#nba-loading").addClass("sloading") 
            this.kissMetricTrackingCode(nba.key)
            this.similar_tickets = [];
            this.widget_pos = 1;
            this.cardCount = 0;
            this.offEventBinding();
            this.addListeners();
            this.removedCards =0;
            this.sas_ids ="Ticket Id's = ";
            this.isFirstRes = true;
        }
        },

        addListeners: function() {
            $(document).on("click.nba", ".sas-hd", this.addNBAWidget.bind(this));
            $(document).on("click.nba", "#nba-nxt", this.addNextButton.bind(this));
            $(document).on("click.nba", ".nxt-btn", this.addNextButton.bind(this));
            $(document).on("click.nba", ".prv-btn", this.addPrevButton.bind(this));
            $(document).on("sidebar_loaded", this.initialization.bind(this));
            $(document).on("click.nba", "#nba-prv", this.addPrevButton.bind(this));
            $(document).on("click.nba",".btn-close",this.removeCards.bind(this));
            $(document).on("click.nba",".sas-cards ul li",this.launchTicketPage.bind(this));
            $(document).on("hover.nba",".sas-ctd",this.toggleHoverOverCards.bind(this));
            $(document).on("nba_loaded",this.fillSpanText.bind(this));
            $(document).on("click.nba",".ficon-like",this.thumbsUp.bind(this));
            $(document).on("click.nba",".ficon-dislike",this.thumbsDown.bind(this));
            $(document).on("click.nba","#fdbk-button",this.submitFeedBack.bind(this));
            $(document).on("click.nba","#help",this.showHelp.bind(this));
        },

        offEventBinding: function() {
            $(document).off("click.nba");
            $(document).off("hover.nba");
            $(document).off("nba_loaded");
            $(document).off("sidebar_loaded");
        },

        submitFeedBack: function(event){
            $(".sas-fdbk-txt").addClass("sas-hidden");
            $(".sas-fdbk").addClass("sas-hidden");
            $("#thanksID").addClass("sas-hidden");
            $("#textthanksID").removeClass("sas-hidden");
            event.preventDefault(); 
            this.pushEventToKM("NBA_BETA_FeedBack_No_Text",this.userProperties(0,$("#sas-fdbk-txt").val(),0));
        },

        showHelp: function(event){
            inline_manual_player.activateTopic("22248"); 
            event.stopPropagation();
            event.preventDefault();
        },

        thumbsUp: function(event){
            $(".sas-fdbk-txt").addClass("sas-hidden");
            $(".sas-fdbk").addClass("sas-hidden");
            $("#textthanksID").addClass("sas-hidden");
            $("#thanksID").removeClass("sas-hidden");
            event.preventDefault(); 
            this.pushEventToKM("NBA_BETA_FeedBack_Yes",this.userProperties(0,"",0));
        },

        thumbsDown: function(event){
            $(".sas-fdbk-txt").removeClass("sas-hidden");
            $(".sas-fdbk").addClass("sas-hidden");
            $("#textthanksID").addClass("sas-hidden");
            $("#thanksID").addClass("sas-hidden");
            event.preventDefault(); 
            this.pushEventToKM("NBA_BETA_FeedBack_No",this.userProperties(0,"",0));
        },

        restoreDefaultFdbk: function(event){
            $(".sas-fdbk-txt").addClass("sas-hidden");
            $(".sas-fdbk").removeClass("sas-hidden");
            $("#textthanksID").addClass("sas-hidden");
            $("#thanksID").addClass("sas-hidden");
            $("#sas-fdbk-txt").val("");
            event.preventDefault(); 
        },

        fillSpanText: function(event){
            this.cardCount = Math.floor(($('.sas-hd').width()/$('.sas-cards ul li').width()) - 1)
            count_text = (((this.widget_pos - 1) * this.cardCount) + 1) + "-" + ((this.widget_pos * this.cardCount < this.similar_tickets.length) ? this.widget_pos * this.cardCount : this.similar_tickets.length) + " of " + this.similar_tickets.length;
            $(".sas-nav span").text(count_text)
            if(jQuery("#all_notes").children().length ==0 || jQuery("#all_notes").children(".conversation").children(".commentbox-gray").length == 0)
            {
                this.isFirstRes = false;
                this.addNBAWidget(event)
            }
        },

        toggleHoverOverCards: function(){   
             if (this.widget_pos * this.cardCount < (this.similar_tickets.length-this.removed_cards.length)) {
                $('.nxt').fadeToggle();
              }
              else{
                if($('.nxt').css("display")=="block"){
                    $('.nxt').css("display","none")
                }
              }
              if(this.widget_pos != 1)
              {
                $('.prv').fadeToggle();
              }
            },

        //Function to expand the NBA widget
        addNBAWidget: function(event) {
            if (!($("#sas-hd-error").hasClass("sas-hidden"))){
                $(".nba-sas").addClass("sas-hidden")
                $("#nba-loading").addClass("sloading")
                this.load_nba_widget(event);
                event.preventDefault(); 
                return 
            }
            if (!($("#sas-hd-no-result").hasClass("sas-hidden"))){
                event.preventDefault(); 
                return 
            }
            $(".sas-hd i").toggleClass("ficon-caret-right ficon-caret-down");
            if ($("#show span").text() == "Show") {
                $("#sas-pnl").removeClass("sas-hidden");
                $("#show span").text("Hide");
                $(".sas-hd").addClass("opened");
                event.preventDefault()
                this.pushEventToKM("NBA_BETA_Expanded",this.userProperties(0,"",0));
                return;
            }
            if ($("#show span").text() == "Hide") {
                $(".sas-hd").removeClass("opened");
                $("#sas-pnl").addClass("sas-hidden")
                $("#show span").text("Show");
                event.preventDefault()
                return;
            }
        },

        //Fucntion to show the next set of similar tickets
        addNextButton: function(event) {
            this.cardCount = Math.floor(($('.sas-ctd').width()/$('.sas-cards ul li').width()) - 1)
            temp_array = []
            if (this.similar_tickets.length > this.widget_pos * this.cardCount) {
                for(i =0;i<this.removed_cards.length;i++)
                {
                  index = ((this.widget_pos-1)*this.cardCount)+parseInt(this.removed_cards[i])
                  index = index-i
                  this.similar_tickets.splice(index, 1);  
                }
                this.removed_cards = []
                temp_array = this.similar_tickets.slice(this.widget_pos * this.cardCount, (this.widget_pos * this.cardCount > this.similar_tickets.length) ? this.widget_pos * this.cardCount : this.similar_tickets.length)
                this.widget_pos = this.widget_pos + 1;
                this.load_similartickets_widget(temp_array);
            }
            this.restoreDefaultFdbk(event);
            event.preventDefault();
            this.pushEventToKM("NBA_BETA_Next_Clicked",this.userProperties(0,"",0));
        },

        launchTicketPage: function(event) {
            index = $(event.currentTarget).attr("data-index")
            if((index - this.removedCards)== this.cardCount){
                this.addNextButton(event)
                return
            }
            window.open(jQuery(event.currentTarget).attr("data-id"), "_blank")
            event.stopPropagation();
            event.preventDefault();
            this.pushEventToKM("NBA_BETA_Link_Clicked",this.userProperties(0,"",jQuery(event.currentTarget).attr("data-id")));
        },

        //Function to show the previous set of similar tickets
        addPrevButton: function(event) {
            this.cardCount = Math.floor(($('.sas-ctd').width()/$('.sas-cards ul li').width()) - 1)
            temp_array = []
            if (this.widget_pos != 1) {
                this.removed_cards.sort()
                for(i =0;i<this.removed_cards.length;i++)
                {
                  index = ((this.widget_pos-1)*this.cardCount)+parseInt(this.removed_cards[i])
                  index = index-i
                  this.similar_tickets.splice(index, 1);  
                }
                this.removed_cards = []
                this.widget_pos = this.widget_pos - 1;
                temp_array = this.similar_tickets.slice((this.widget_pos - 1) * this.cardCount, ((this.widget_pos - 1) * this.cardCount > this.similar_tickets.length) ? (this.widget_pos) * this.cardCount : this.similar_tickets.length)
                this.load_similartickets_widget(temp_array);
            }
            this.restoreDefaultFdbk(event);
            event.preventDefault();
            this.pushEventToKM("NBA_BETA_Prev_Clicked",this.userProperties(0,"",0));
        },

        removeCards: function(event) {
            this.removedCards=this.removedCards+1;
            jQuery(event.currentTarget).parent("li").fadeOut();
            index = $(event.currentTarget).parent("li").attr("data-index")
            this.removed_cards.push(parseInt(index))
            //index = ((this.widget_pos-1)*this.cardCount)+parseInt(index)
            //this.similar_tickets.splice(index, 1);
            //this.toggleHoverOverCards()
            if (!(this.widget_pos * this.cardCount < (this.similar_tickets.length-this.removed_cards.length)))
            {
             if($('.nxt').css("display")=="block"){
                    $('.nxt').css("display","none")
                }   
            }
            this.cardCount = Math.floor(($('.sas-hd').width()/$('.sas-cards ul li').width()) - 1)
            count_text = (((this.widget_pos - 1) * this.cardCount) + 1) + "-" + ((this.widget_pos * this.cardCount < (this.similar_tickets.length-this.removed_cards.length)) ? this.widget_pos * this.cardCount : (this.similar_tickets.length-this.removed_cards.length)) + " of " + (this.similar_tickets.length-this.removed_cards.length);
            $(".sas-nav span").text(count_text)
            if(((this.widget_pos-1)*this.cardCount) >= (this.similar_tickets.length-this.removed_cards.length)){
                if(this.widget_pos>1)
                {
                    this.addPrevButton(event)
                }
                else
                {
                    this.load_no_response_widget("empty_response", event);
                }
            }
            event.stopPropagation();
            event.preventDefault();
            this.pushEventToKM("NBA_BETA_Closed_Ticket",this.userProperties($(event.currentTarget).parent("li").attr("data-id"),"",0));
        },

        //NBA api is triggered after the complete ticket details page is loaded
        initialization: function(e) {
             this.load_nba_widget(e);
        },

        //Trigger to get the similar tickets and call the populate NBA widget function
        load_nba_widget: function(event) {
            $this = this
            $.ajax({
                url: window.location.pathname + "/suggest/tickets",
                contentType: "application/json",
                type: "GET",
                success: function(response) {
                    $("#nba-loading").removeClass("sloading")
                    if (response.length > 0) {
                        $this.process_response(response, event);
                    } else {
                        $this.load_no_response_widget("empty_response", event);
                    }
                },
                error: function(xhr, textStatus, errorThrown) {
                    $("#nba-loading").removeClass("sloading")
                    $this.load_no_response_widget("error", event);
                }
            })
        },

        //Method to process the reponse from the Ajax call
        process_response: function(response, event) {
            sas_ids="";
            $.each(response, function(index, value) {
                sas_ids = sas_ids + value["helpdesk_ticket"]["display_id"].toString()+", ";
            });
            this.similar_tickets = response
            this.load_similartickets_widget(response)
            $(".sas-cnt").text(this.similar_tickets.length)
            this.cardCount = Math.floor(($('.sas-ctd').width()/$('.sas-cards ul li').width()) - 1)
            count_text = (((this.widget_pos - 1) * this.cardCount) + 1) + "-" + ((this.widget_pos * this.cardCount < this.similar_tickets.length) ? this.widget_pos * this.cardCount : this.similar_tickets.length) + " of " + this.similar_tickets.length;
            $(".sas-nav span").text(count_text)
            if (this.similar_tickets.length > this.cardCount) {
                $("#nxt").removeClass("dbl")
            }
            $(".nba-sas").removeClass("sas-hidden")
            this.sas_ids = sas_ids;
            trigger_event("nba_loaded",{});
            event.preventDefault();
        },

        //Method to load widget when there is no response to render
        load_no_response_widget: function(msg, event) {
            if (msg == "error") {
                $(".nba-sas").removeClass("sas-hidden")
                $("#sas-pnl").addClass("sas-hidden")
                $("#sas-hd-no-result").addClass("sas-hidden")
                $("#sas-hd-result").addClass("sas-hidden")
                $("#sas-hd-error").removeClass("sas-hidden")
            } else {
                $(".nba-sas").removeClass("sas-hidden")
                $("#sas-pnl").addClass("sas-hidden")
                $("#sas-hd-no-result").removeClass("sas-hidden")
                $("#sas-hd-result").addClass("sas-hidden")
                $("#sas-hd-error").addClass("sas-hidden")

            }
            event.preventDefault()
        },

        userProperties: function(closedTicket,feedback_text,childTicket){
            return {
                         'account_id': current_account_id,
                         'fields':current_account_id+'$$'+nba.ticket.id+'$$'+nba.ticket.responder.id+'$$'+nba.ticket.group.id+'$$'+this.isFirstRes+'$$'+nba.ticket.source+'$$'+nba.ticket.status+'$$'+nba.ticket.ticket_type+'$$'+current_user_id+'$$'+this.widget_pos+'$$'+this.cardCount+'$$'+closedTicket+'$$'+childTicket+'$$'+feedback_text+'$$'+this.sas_ids,
                    }
        },

        pushEventToKM: function(eventName,prop){
            this.push_event(eventName,prop);

        },

        //Seperate function to populate NBA widget
        load_similartickets_widget: function(response) {
            $(".sas-cards").html("")
            maxHeight = 0;
            list = "<ul>"
            $.each(response, function(index, value) {
                if((value["helpdesk_ticket"]["subject"]).length > 25){
                    value["helpdesk_ticket"]["subject"] = value["helpdesk_ticket"]["subject"].substring(0, 25)+"..."
                }
                 if((value["helpdesk_ticket"]["description"]).length > 150){
                    value["helpdesk_ticket"]["description"] = value["helpdesk_ticket"]["description"].substring(0, 150)+"..."
                }
               
                tempateVariables = {
                        index:index,
                        display_id: value["helpdesk_ticket"]["display_id"],
                        requestor_name: value["helpdesk_ticket"]["requester_name"],
                        subject: value["helpdesk_ticket"]["subject"],
                        updated_at: value["helpdesk_ticket"]["updated_at"],
                        status_name: value["helpdesk_ticket"]["status_name"],
                        description: value["helpdesk_ticket"]["description"]
                    },
                    list += JST["tickets/templates/suggest-ticket-cards"](tempateVariables);
            })
            list += JST["tickets/templates/suggest-ticket-cards-navigation"]();
            count_text = (((this.widget_pos - 1) * this.cardCount) + 1) + "-" + ((this.widget_pos * this.cardCount < this.similar_tickets.length) ? this.widget_pos * this.cardCount : this.similar_tickets.length) + " of " + this.similar_tickets.length;
            $(".sas-cards").append(list)
            $(".sas-nav span").text(count_text)
            if (this.widget_pos > 1) {
                $("#prv").removeClass("dbl")
            } else {
                $("#prv").addClass("dbl")
            }
            if (this.widget_pos * this.cardCount < this.similar_tickets.length) {
                $("#nxt").removeClass("dbl")
            } else {
                $("#nxt").addClass("dbl")
            }
            $('.sas-cards ul li').each(function() {
             maxHeight = maxHeight > $(this).height() ? maxHeight : $(this).height();
            }); 

            $('.sas-cards ul li').each(function() {
             $(this).height(maxHeight);
            });
        },

        push_event: function (event,property) {
            if(typeof (_kmq) !== undefined ){
                this.recordIdentity();
                _kmq.push(['record',event,property]);   
            }
            
        },

        getIdentity: function(){
            return current_account_id;
        },

        recordIdentity: function(){
            if(typeof (_kmq) !== undefined ){
                _kmq.push(['identify', this.getIdentity()]);
            }
        },

        kissMetricTrackingCode: function(api_key){
                var _kmq = _kmq || [];
                var _kmk = _kmk || api_key;
                function _kms(u){
                  setTimeout(function(){
                    var d = document, f = d.getElementsByTagName('script')[0],
                    s = d.createElement('script');
                    s.type = 'text/javascript'; s.async = true;
                    s.onload = function() {
                        trigger_event("script_loaded",{});
                    };
                    s.src = u;
                    f.parentNode.insertBefore(s, f);
                  }, 1);
                }
                _kms('//i.kissmetrics.com/i.js');
                _kms('//scripts.kissmetrics.com/' + _kmk + '.2.js');
                

        }

    };
}(window.jQuery));