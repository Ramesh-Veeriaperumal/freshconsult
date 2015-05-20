/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
(function ($) {
  "use strict";

  App.Solutions = {
    current_module: '',

    onFirstVisit: function (data) {
      this.onVisit(data);
    },
		
    onVisit: function (data) {
      this.setSubModule();
      if (this.current_module !== '') {
        this[this.current_module].onVisit();
      }
      App.Solutions.Reorder.start();
			App.Solutions.NavMenu.start();
    },

    setSubModule: function () {
      switch (App.namespace) {
      case "solution/manage":
        this.current_module = 'Manage';
        break;
      case "solution/articles/edit":
      case "solution/articles/show":
      case "solution/articles/new":
        this.current_module = 'Article';
				break;
      case "solution/categories/index":
        App.Solutions.sideBar.onVisit();
        App.Solutions.feedbacksideBar.onVisit();
        break;
      }
    },

    onLeave: function (data) {
      if (this.current_module !== '') {
        this[this.current_module].onLeave();
        this.current_module = '';
      }
      App.Solutions.Reorder.leave();
    }
  };


  // will move this to seperate file and extract common methods to prototype

  App.Solutions.feedbacksideBar = {
    myFeedbacks: '',
    allFeedbacks: '',

    onVisit: function () {
      $('#solution-home-sidebar').trigger('afterShow');
      this.addListeners();
    },

    addListeners: function () {
      $("body").on('click.sidebar', '#feedbacks-me, #feedbacks-all', this.refreshSideBar.bind(this));
    },

    refreshSideBar: function (ev) {
      var target = ev.target.id;
      if (target === 'feedbacks-all') {
        this.setAllFeedbacks();
      } else if (target === "feedbacks-me") {
        this.setMyFeedbacks();
      }
    },

    setMyFeedbacks: function () {
      if (this.myFeedbacks.empty()) {
        this.myFeedbacks = $('#feedbacks-sb').html();
      }
      $('#feedbacks-sb').html(this.myFeedbacks);
    },

    setAllFeedbacks: function () {
      if (this.myFeedbacks.empty()) {
        this.myFeedbacks = $('#feedbacks-sb').html();
      }
      if (this.allFeedbacks.empty()) {
        this.fetchAllFeedbacks();
      }else{
        $('#feedbacks-sb').html(this.allFeedbacks);
      }
    },

    fetchAllFeedbacks: function () {
      var $this = this;
      $.ajax({
          type: 'GET',
          url:  '/solution/categories/feedbacks',
          data: { scope: "all"},
          dataType: 'html',
          success: function (allFeedbacks) {
            $this.allFeedbacks = allFeedbacks;
            $('#feedbacks-sb').html($this.allFeedbacks); 
          },
          error: function(){
            console.log('inside fetch feedback failure');
          }
      });
    }


  };



  App.Solutions.sideBar = {
    myDrafts: '',
    allDrafts: '',

    onVisit: function () {
      $('#solution-home-sidebar').trigger('afterShow');
      this.addListeners();
    },

    addListeners: function () {
      $("body").on('click.sidebar', '#drafts-me, #drafts-all', this.refreshSideBar.bind(this));
    },

    refreshSideBar: function(ev) {
      var target = ev.target.id;
      window.foo = target;
      if (target == 'drafts-all'){
        this.setAllDrafts();
      } else if (target == "drafts-me") {
        this.setMyDrafts();
      }
    },

    setMyDrafts: function() {
      if (this.myDrafts.empty()){
        this.myDrafts = $('#drafts-sb').html(); 
      }
      $('#drafts-sb').html(this.myDrafts);
    },

    setAllDrafts: function () {
      if (this.myDrafts.empty()){
        this.myDrafts = $('#drafts-sb').html(); 
      }

      if(this.allDrafts.empty()){
        this.fetchAlldrafts();
      }else{
        $('#drafts-sb').html(this.allDrafts);
      }
    },

    fetchAlldrafts: function () {
      var $this = this;
      $.ajax({
          type: 'GET',
          url:  '/solution/categories/drafts',
          data: { scope: "all"},
          dataType: 'html',
          success: function (allDrafts) {
            window.alliswell = allDrafts;
            $this.allDrafts = allDrafts;
            $('#drafts-sb').html($this.allDrafts); 
          },
          error: function(){
            console.log('inside fetch draft failure');
          }
      });
    }
  };
}(window.jQuery));