// PROFILE AVATARS 
(function($){
  "use strict";
  var AvatarReader = function(options) {
    var defaults = {
      confirmDeleteMessage : 'Are you sure you want to delete this picture?',
      ie9FileChangeMessage : 'You have selected %{filename}. Click save to see the changes.',
      // Path of the default avatar pic
      defaultPath: PROFILE_BLANK_MEDIUM_PATH,
      // Array of supported image formats
      supportedImageFormats : ['image/jpeg', 'image/png'],
      // Selector that wraps the avatar options change & delete
      avatarContainer: '.avatar-options',
      // Selector of the form
      formContainer: 'form.form-unsaved-changes-trigger',
      // Selectors of the innerfields
      fields: {
        // Img Tag to show the pic
        avatarPic : '.avatar-pic img',
        // Input File Tag
        avatarFile : '.avatar-file',
        // Remove Pic link
        avatarRemove : '.remove-avatar',
        // destroy param to indicate whether the avatar is removed
        avatarDestroy : '.avatar-destroy',
        avatarText : '.avatar-text',
        ie9FileChangeElmt: '.ie9-file-change-msg'
      }
    };
    this.options = $.extend({}, defaults, options);
  };

  AvatarReader.prototype = {
    onFileChange : function(e) {
      var fileField = e.currentTarget,
          fileName = this.options.fields.avatarFile.val(),
          isIE9 = $('html').hasClass('ie9'),
          extension = '';
      if( (isIE9 && fileName != "" ) || 
            (fileField.files && fileField.files[0] && this.checkSupportedImageFormats(fileField.files[0].type)) ){
            if(isIE9) {
              fileName = fileName.replace(/^.*\\/, "");
              extension = fileName.match(/\.[0-9a-z]{1,5}$/i);
              fileName = (fileName.length > 25) ? fileName.substring(0,25) + '...' + extension : fileName;
              fileName = this.options.ie9FileChangeMessage.replace('%{filename}', '<b>' + fileName + '</b>');
              this.setDefaultPic();
              (this.options.fields.ie9FileChangeElmt).html(fileName).show();
            }
            else {
              this.readLocalFile(fileField.files[0]);
            }
            this.toggleRemoveOption('show');
            this.changeAvatarText('Change');
            this.updateDestroyValue("0");
      }
      else {
        this.setDefaultPic();
        this.toggleRemoveOption('hide');
        this.changeAvatarText('Add Photo');
      }
    },
    readLocalFile : function(file) {
      var fileReader = new FileReader();
      var self = this;
      fileReader.readAsDataURL(file);
      fileReader.onload = function(evt) {
        self.localFileOnLoad(evt)
      }
    },
    localFileOnLoad : function(evt) {
      (this.options.fields.avatarPic).attr('src', evt.target.result);
    },
    checkSupportedImageFormats : function(fileType) {
      return ($.inArray(fileType, this.options.supportedImageFormats) !== -1)
    },
    toggleRemoveOption : function(option) {
      (this.options.fields.avatarRemove)[option]();
    },
    changeAvatarText : function(text) {
      (this.options.fields.avatarText).text(text);
    },
    updateDestroyValue : function(value) {
      if((this.options.fields.avatarDestroy).val() != -1) {
        (this.options.fields.avatarDestroy).val(value);
        this.updateFormChanges(true);
      }
    },
    updateFormChanges : function(option) {
      (this.options.formContainer).data('formChanged', option);
    },
    setDefaultPic : function() {
      (this.options.fields.avatarPic).attr('src', this.options.defaultPath);
    },
    resetPicField : function() {
      (this.options.fields.avatarFile).replaceWith( (this.options.fields.avatarFile) = (this.options.fields.avatarFile).clone( true ) );
      (this.options.fields.ie9FileChangeElmt).html('').hide();
    },
    removePic : function() {
      var confDelete = confirm(this.options.confirmDeleteMessage);
      if(confDelete) {
        this.changeAvatarText('Add Photo');
        this.resetPicField();
        this.updateDestroyValue("1");
        this.setDefaultPic();
        this.toggleRemoveOption('hide');
      }
    },
    init : function() {
      var self = this;
      for(var prop in this.options.fields) {
        if(prop == 'avatarPic' || prop == 'ie9FileChangeElmt') {
          this.options.fields[prop] = $(this.options.fields[prop]);
        }
        else {
          this.options.fields[prop] = $(this.options.avatarContainer).find(this.options.fields[prop]);
        }
      }
      this.options.formContainer = $(this.options.avatarContainer).parents(this.options.formContainer);
      $(document).on('change.avatar-reader', (this.options.fields.avatarFile).selector, function(e) {
        self.onFileChange(e);
      });
      $(document).on('click.avatar-reader', (this.options.fields.avatarRemove).selector, function(e) {
        e.preventDefault();
        self.removePic();
      });
    },
    destroy: function() {
      $(document).off('click.avatar-reader');
      $(document).off('change.avatar-reader');
    }
  };

  $(document).ready(function(){
    var avatarRdr = new AvatarReader({
                          confirmDeleteMessage : customMessages.confirmDelete,
                          ie9FileChangeMessage : customMessages.ie9FileChangeMsg
                        });
    avatarRdr.init();
  });
})(window.jQuery);