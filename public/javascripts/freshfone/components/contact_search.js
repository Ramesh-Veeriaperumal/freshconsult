var FreshfoneContactSearch;
(function ($) {
    "use strict";
  var regex = /^.*[a-zA-Z].*|.*\d.*$/,
  numberRegex = /\W|(^[0-9.]|\+)[0-9]*$/,
  	 specCharRegex = /^[a-zA-Z0-9]*$/;
  FreshfoneContactSearch = function () {
	   this.$container = $('#search_bar');
		this.init();
	};

	FreshfoneContactSearch.prototype = {
		init: function () {
			this.$searchList = this.$container.find('.contact_results_info');
			this.$searchedNumber = this.$searchList.find('.searched-number');

			this.bindSearchList();
			this.bindSearchedNumber();
		},

		bindSearchList: function(){
			var self = this;
			this.$searchList.on('mouseover', '.search-result', function(){
			 	var $prevElem = self.$searchList.find('.active-element');	
				freshfoneDialpadEvents.makeActive($prevElem,$(this)); 	

	  	}).on('click', '.search-result', function(){
	  		if($(this).hasClass('do-not-make-call')) { return; }
		    var $parentElem = $(this).parents('li'),
		    	 freshfone_number = $(this).find(".phone-contact").text().trim();
		    freshfoneDialpadEvents.updateNumber(freshfone_number,$parentElem);
			});
		},

		bindSearchedNumber: function(){
			this.$container.on('click', '.searched-number', function(){
				if( $(this).hasClass('make-call')) {
					return freshfonecalls.makeCall($(this).parents("li"));	
				}
			}).on('mouseover', '.searched-number', function(){
				$(this).addClass("active-element");

		  }).on('mouseleave', '.searched-number', function(){
		    $(this).removeClass("active-element");
		  });	
		},

		isValidSearchString: function(searchString){
			return (searchString.length >= 2 && regex.test(searchString))
		},

		isVaildeNumberString: function(dialedNumber) {
			return numberRegex.test(dialedNumber);
		},
		replaceSpecChar: function(result_string){
			if(!specCharRegex.test(result_string)){
				result_string = result_string.replace(result_string.charAt(0),'');
			}
			return result_string;
		},

		getSearchResults: function(string){
		  var self = this;
		  $.ajax({ 
	  		url: '/freshfone/autocomplete/customer_contact',
	  		method: 'GET',
	  		allowClear: true,
	  		data: { q: string },
	  		dataType : "html",
				success: function(data){
					self.$searchList.find('.search_result_container').html(data);
					self.appendNoResults(string);
				}
			});	
		},

		appendNoResults: function(string){
			var regex = /[a-zA-Z]/;
			this.$container.show();
			if(regex.test(string) && (this.$searchList.find('.no-search-result').length == 1)){
				var $direct_dial = this.$searchList.find('.direct_dial')
				 $direct_dial.addClass('do-not-make-call');
				 $direct_dial.find('.ff_call_button').toggle(false);
				 $direct_dial.find('.result-phone').text("No results found");
			} 
	  }
	};

}(jQuery));