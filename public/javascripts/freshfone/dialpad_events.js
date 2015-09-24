var FreshfoneDialpadEvents
(function ($) {
  	"use strict";  
  var freshfone_number,
  		isSearchBar = false,
  		currentString = '',
  		formattedString,
  		addDelay;

  FreshfoneDialpadEvents = function () {
		this.init();
		addDelay = this.addTimeOut();
	};

	FreshfoneDialpadEvents.prototype = {
		init: function () {
				this.$dialpadContainer = $('.ff-dial-pad');
				this.$number = this.$dialpadContainer.find('#number');
				this.$dialpadIcon = $('#freshfone_dialpad .dialpad_icon');
			   this.$searchContainer = this.$dialpadContainer.find('#search_bar');
			   this.$searchList = this.$searchContainer.find('.contact_results_info');
			   this.$contactDetails = this.$dialpadContainer.find('.contact-details-msg');
			   this.$recentCallContainer = $('#recent_calls');
			   this.$outgoing_numbers_list = this.$dialpadContainer.find('.outgoing_numbers_list');
			   this.$selectedFlag = this.$dialpadContainer.find('.selected-flag');
			   this.$activeRecentCall = $('.recent_calls_container .active-element');

			   this.bindRecentCallsEvent();
			   this.bindAllScrollEvent();
			   this.bindOutgoingSelect2();
			   this.bindNumberChangeEvent();
			   this.bindOutgoingNumberEvent();
			   this.bindConnectedCallEvent();
			   this.bindDialpadIconEvent();
			   this.bindHideCountryList();
			   this.bindCountryListVisibility();
			   this.unbindContactLinks();
			   this.$number.intlTelInput("initPreferredCountries");
		},

		$connectedCallTemplate: $('#ffone-connected-call-template'),


		bindRecentCallsEvent: function(){
			var self = this;
			this.$recentCallContainer.on('mouseover', '.recent_call_entry', function(){
		    var $prevElem = self.$recentCallContainer.find('.active-element');
		    self.makeActive($prevElem,$(this)); 

		  }).on('click', '.recent_call_entry', function(){
		    freshfone_number = $(this).attr('data-phone-number');
		    self.updateNumber(freshfone_number,$(this));
		  });
		},

		bindAllScrollEvent: function(){
			var self = this;
			$(document).on( 'mousewheel DOMMouseScroll', '.contact_results_info, .outgoing_numbers_list_dropdown ul', function(ev){
	      if( ev.originalEvent ) ev = ev.originalEvent;
	      var delta = ev.wheelDelta || -ev.detail;
	      this.scrollTop += ( delta < 0 ? 1 : -1 ) * 10;
	      ev.preventDefault();
	      self.$number.keypad('hide');
	  	});
		},

		bindNumberChangeEvent: function(){
			var self = this;
			this.$number.on('input',function(e){
				var searchString = $(this).val();
				self.updateDirectDialNumber(searchString);
				self.bindSearchResult(searchString);
			});

			this.$number.on('change',function(e){
				var searchString = $(this).val();
				isSearchBar = (searchString != '');
			});
		},	


		bindSearchResult: function(searchString){
			var self = this;
			if (searchString == ''){
			 self.bindEmptySearchResult();
			 return;
			}
			self.$searchContainer.show(); 
			if($(this).data("lastval") != searchString){
				$(this).data("lastval",searchString);
				addDelay(function(){
					formattedString = freshfoneContactSearch.replaceSpecChar(searchString);
					if (freshfoneContactSearch.isValidSearchString(formattedString)){
		      	self.contactSearch(searchString);
		      }
		    }, 450 );
			}
		},

		addTimeOut: function(){
			var timer = 0;
		  return function(callback, ms){
		    clearTimeout(timer);
		    timer = setTimeout(callback, ms);
	  	};
		},
	 
		bindOutgoingSelect2: function(){
			var self = this;
			$(document).ready(function(){
	    	if (! $.isEmptyObject(freshfone.numbersHash)) {
		      freshfonewidget.outgoingCallWidget.toggle(true);
		      self.$outgoing_numbers_list.select2({
		        dropdownCssClass: "outgoing_numbers_list_dropdown",
		        minimumResultsForSearch: 5,
		        attachtoContainerClass: ".popupbox-content.freshfone_content_container",

		        formatResult: function(result, container,query){
	            var name = freshfone.namesHash[result.id],
	            number = freshfone.numbersHash[result.id];
	            if(name == ""|| name.trim == "" ){
	              return  "<span>" +number + "</span>" ;
	            } else{
	             	return "<span><b>" + name + "</b></span><br/><span>" + number + " </span>" ;    
	          	}
		        },
		        
		        formatSelection: function(data, container) {
		          var result = data.text;
		          var lastindex = result.lastIndexOf(" ");
		          result = (lastindex > -1) ?  result.substring(0, lastindex) : data.text;
		          return result;
		        }
		      });
		      $(".caller_id_icon").on('click', function(){
				 		var select2 = $('#s2id_outgoing_number_selector').data('select2');
				 		if(typeof select2 != "undefined") {
				 			select2.open();
				 		}
					});
		    } else { 
		      freshfonewidget.outgoingCallWidget.toggle(false);
		    }
	  	});
			
		},

		bindOutgoingNumberEvent: function(){
			this.$outgoing_numbers_list.on('change',function(){
		    var callerIdNumber = $('.outgoing_numbers_list').select2("val");
		    localStorage.setItem("callerIdNumber", callerIdNumber);
		    $('#outgoing_number_selector').find('.li_opt_selected').removeClass("li_opt_selected");
		    $('#outgoing_number_selector option:selected').addClass("li_opt_selected");
 		 	}); 
		},

		bindConnectedCallEvent: function(){
			var self = this;
			this.$contactDetails.on('click','#cancel_call',function(){
    		self.hideContactDetails();

			}).on('click','.connect_call',function(){
    		return freshfonecalls.makeCall();

  		}).on('click','#back_to_dialer',function(){
   	 		self.hideContactDetails();

   	 	});
		},

		bindDialpadIconEvent: function(){
			var self = this;
			this.$dialpadIcon.on('click',function(){
      	$('.freshfone_dialpad').is(':visible') ? self.$number.keypad('hide') : self.$number.keypad('show');
  		});
		},

		bindHideCountryList: function(){
			var self = this;	
			this.$dialpadContainer.find('.backArrow').bind('click',function(){
				$('.countrySearch,.country-list').addClass("hide");
				$('.selected-flag').trigger("ffCountryFlagList:off");
	    	self.$selectedFlag.removeClass("hide");
	    	self.$number.focus(); 
	    });
		}, 

		bindEmptySearchResult: function(){
			isSearchBar = false;
			this.$searchContainer.hide(); 	
			this.$activeRecentCall.addClass('active-element');
		}, 

		showDialpadElem: function(){
			this.$number.val('').focus();
			this.$searchContainer.hide();	
			this.$contactDetails.hide();	
		},

		contactSearch: function(searchString){		
	  	isSearchBar = true;
	  	this.$activeRecentCall.removeClass('active-element');
	    this.$searchContainer.show();
			if (this.isNumeric(searchString)) { 
				searchString = freshfonecalls.addDialCode(searchString);
			}
	    freshfoneContactSearch.getSearchResults(searchString);      
		},

		getContactDetails: function(contactElement,$item){
			return $item.find(contactElement).text().trim();
		},

		contactAvatar: function ($item) {
			return $item.find('.ff_profile_img').html();
		},
		contactName: function($item){
		  var contactNameElem = ($item.is('.no-search-result')) ? $('.no_results') : $('.result-name');
		  return this.getContactDetails(contactNameElem,$item);
		},

		contactNumber: function($item){
			var contactNumberElem = $('.active-element').find('.result-phone');
			return this.getContactDetails(contactNumberElem,$item);
		},

		contactCompany: function($item){
			var contactCompanyElem = $('.result-company');
			return this.getContactDetails(contactCompanyElem,$item);
		},

		prefillConnectedCallTemplate: function($item){
			var template = this.$connectedCallTemplate.clone(),
				params = {
					contact_name: this.contactName($item),
					contact_number: this.contactNumber($item),
					contact_company: this.contactCompany($item),
					contact_avatar: this.contactAvatar($item)
				};

			$(".call-details-msg").html(template.tmpl(params));
			this.$contactDetails.show('fade', {direction: 'right'}, 50);
		},

		prefillConnectedCallNumber:function(number) {
			var template = this.$connectedCallTemplate.clone(),
			params = { contact_number: number };
			$(".call-details-msg").html(template.tmpl(params));
			this.$contactDetails.show('fade', {direction: 'right'}, 50);
		},

		hideContactDetails: function(){
			this.$contactDetails.hide();
			this.$number.focus();
		},

		makeActive: function(current_element,next_element){
	  	current_element.removeClass("active-element");
	  	next_element.addClass("active-element");
	  },

	  updateNumber: function(freshfone_number,item){
	  	this.$number.val(freshfone_number);
			this.$number.intlTelInput("updateFlag");
			return freshfonecalls.makeCall(item);
	  },

	  nextElement: function (key) {
			var	container = this.currentContainer(),
					current_element = container.find('.active-element'),
					next;

					if (typeof(current_element[0]) == "undefined") { 
						this.makeFirstElementActive();
					}
			next = (key == 40) ? this.getNextElement(current_element) : this.getPrevElement(current_element);
			this.makeActive(current_element,next);
			this.scrollTo(container,next);	
		},

		bindEnterEvent: function(){
			var	container = this.currentContainer(), self = this,
					current_element = container.find('.active-element');
			if (typeof(current_element[0]) == "undefined") { this.directDial(); return; }
			isSearchBar ? this.searchEnter(current_element) : this.recentCallsEnter(current_element);
		},
		directDial: function() {
			var dialedNumber = this.$number.val();
			if (freshfoneContactSearch.isVaildeNumberString(dialedNumber)) {
				this.updateNumber(dialedNumber);
			}
		},
		makeFirstElementActive: function () {
			var firstElementClass = isSearchBar ? ".search-result:visible:first" : ".recent_call_entry:first";
			$(this.currentContainer()[0]).find(firstElementClass).addClass("active-element");
		},
		currentContainer: function() {
			return isSearchBar ? $('.contact_results_info') : $('.recent_calls_container');
		},

		getNextElement: function(current_element) {
			if (current_element.next().length) { return current_element.next(); }
			if (isSearchBar) { return this.nextElementOfSearch(current_element); }
			return $('.recent_calls_container').find('div .recent_call_entry :first');
		},

		nextElementOfSearch: function(current_element){
			 var next_element = "";
			 if (this.$searchList.find('li :last').is(current_element)) {
			 	 next_element = this.$searchList.find('li :first .contact-num').find('li:first') 
			 	} else if (this.isDirectDialElement(current_element)) {
			 		next_element = current_element.parents('li').next().find('.contact-num:first li:first')
			 	} else {
			 		next_element = current_element.parents("li").next().find("li:first");
			 	}
			 	return next_element;
		},

		getPrevElement: function(current_element) {
			var elementType = isSearchBar ? "li" : "div"
			if (current_element.prev(elementType).length) { return current_element.prev(); }
			if (isSearchBar) { return this.prevElementOfSearch(current_element); }
			return current_element;
		},

		prevElementOfSearch: function(current_element) {
			if(this.isDirectDialElement(current_element)){ return current_element  } 
			if (this.$searchList.find('.search_result_container li :first .contact-num li:first').is(current_element)) {
				return this.getDirectDialElementOrCurrent(current_element);
			} else {
				return current_element.parents("li").prev().find("li:last");
			}
		},

		searchEnter: function(current_element) {
			if(current_element.hasClass('do-not-make-call')) {
				return;
			}
			freshfone_number = current_element.find('.phone-contact').text().trim();
			this.updateNumber(freshfone_number,current_element.parents("li"));
		},

		recentCallsEnter: function(current_element) {
			freshfone_number = current_element.attr('data-phone-number');
			this.updateNumber(freshfone_number,current_element);
		},
		scrollTo: function(container,element,middle) {
	   	var containerHeight = container.height(), 
				 containerTop = container.offset().top, 
				 containerBottom = containerTop + containerHeight, 
				 elementHeight = element.outerHeight(), 
				 elementTop = element.offset().top, 
				 elementBottom = elementTop + elementHeight,
				 newScrollTop = elementTop - containerTop + container.scrollTop(), 
				 middleOffset = containerHeight / 2 - elementHeight / 2;

			if (elementTop < containerTop) {
		    // scroll up
		    if (middle) {
		      newScrollTop -= middleOffset;
		    }
		    container.scrollTop(newScrollTop);
			} else if (elementBottom > containerBottom) {
		    // scroll down
		    if (middle) {
		      newScrollTop += middleOffset;
		 		}
			  var heightDifference = containerHeight - elementHeight;
			  container.scrollTop(newScrollTop - heightDifference );
		  }
	  },
	  bindCountryListVisibility: function() {
	  	$('.selected-flag').on("ffCountryFlagList:on",function(){ 
	  		$('.caller_id').hide();
	  	}).on("ffCountryFlagList:off",function(){ 
	  		$('.caller_id').show();
	  	});	  	
	  },
	  unbindContactLinks: function() {
	  	$('body').on("click",'.recent_calls_container a', function(ev){ev.preventDefault(); return false;})
	  },
	  updateDirectDialNumber: function(searchString) {
	  	var $direct_dial = this.$searchList.find('.direct_dial');
	  	if (this.isNumeric(searchString)) { 
	  		searchString = freshfonecalls.addDialCode(searchString);
		  	$direct_dial.toggle(true);
		  	$direct_dial.addClass('active-element');
		  	$direct_dial.find('.result-phone').text(searchString);
	  	} else {
	  		$direct_dial.toggle(false);
	  		$direct_dial.removeClass('active-element');
		  }
	  },
	  isDirectDialElement: function(element) {
	  	return element.hasClass('direct_dial');
	  },
	  isNumeric: function(searchString) {
	  	return /\W|(^[0-9.]|\+)[0-9]*$/.test(searchString);
	  },
	  getDirectDialElementOrCurrent: function(current_element) {
	  	var directDialElem = current_element.parents("li").parent().prev().find("li:visible:last");
	  	return (directDialElem.length > 0) ? directDialElem : current_element;
	  }
	};    
}(jQuery));