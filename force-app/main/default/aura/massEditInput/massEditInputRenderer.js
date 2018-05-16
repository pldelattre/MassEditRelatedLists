({
	// Your renderer method overrides go here
  afterRender: function(component, helper) {
    //Set picklist initial value
  //  helper.setPicklistInitialValue(component,helper);
    //enable or disable the components
    /*
    helper.enableOrDisableFields(component);*/
    this.superAfterRender();

  },

  rerender : function(component, helper){
  //  this.superRerender();
    // do custom rerendering here
  //  helper.setPicklistInitialValue(component,helper);
    //enable or disable the components
  //  helper.enableOrDisableFields(component);*/

  }

})