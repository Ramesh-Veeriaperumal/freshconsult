if(!!App && !!App.CollaborationModel) {
  if(typeof App.CollaborationModel.init === "function") {
    App.CollaborationModel.init();
  }   
  if(typeof App.CollaborationModel.activateBellListeners === "function") {
    App.CollaborationModel.activateBellListeners();
  }   
} else {
  console.warn("Could not start collaboration. Unknown Error."); // Don't init collab
}   