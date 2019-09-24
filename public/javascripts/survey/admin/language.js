var CustomSurveyLanguage = {
  initLoad: function () {
    jQuery(".common-icon-help").hide();
    jQuery(".show-info").hide();
    this.bindEvents();
  },
  bindEvents: function () {
    jQuery(".disable-container").mouseenter(function() {
      jQuery(".show-info").show();
      var top =  jQuery('.disable-container').height()/2;
      jQuery(".show-info").css({ top: top});
    });
    jQuery(".disable-container").mouseleave(function(){
      jQuery(".show-info").hide();
    });
    jQuery(".untranslated").on('click', function(event){
      event.preventDefault();
    });
    window.addEventListener("message", this.handleUpload.bind(this));
  },
  handleUpload : function (event) {
    if (event.data.action == 'survey-translation-uploaded') {
      // Using custom_translation status to change the label in language list 
      var SURVEY_STATUS = { 1: 'Translated', 2: 'Outdated', 3: 'Incomplete' };
      var targetElement = jQuery('#language-'+event.data.languageCode);
      var targetLabel = targetElement.find('.survey-status-label');
      var old_status = targetLabel.text().trim().toLowerCase();
      var new_status = SURVEY_STATUS[event.data.response.data.status];
      this.setStatus(targetLabel, old_status, new_status);
      this.togglePreview(targetElement.find('.preview-survey'), old_status, new_status);
    }
  },
  setStatus : function (targetLabel, old_status, new_status) {
    targetLabel.removeClass('survey-'+old_status);
    targetLabel.addClass('survey-'+new_status.toLowerCase()).text(new_status);
  },
  togglePreview: function (previewElement, old_status, new_status) {
    if (old_status == 'untranslated') {
      previewElement.off('click');
    }
    previewElement.removeClass(old_status);
    previewElement.addClass(new_status.toLowerCase());
  },
  unload : function() {
    window.removeEventListener("message", this.handleUpload.bind(this));
  }
};
