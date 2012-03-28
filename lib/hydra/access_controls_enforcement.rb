module Hydra::AccessControlsEnforcement
  
  def self.included(klass)
    klass.send(:include, Hydra::AccessControlsEvaluation)
  end
  
  #
  #   Access Controls Enforcement Filters
  #
  
  # Controller "before" filter that delegates enforcement based on the controller action
  # Action-specific implementations are enforce_index_permissions, enforce_show_permissions, etc.
  # @param [Hash] opts (optional, not currently used)
  #
  # @example
  #   class CatalogController < ApplicationController  
  #     before_filter :enforce_access_controls
  #   end
  def enforce_access_controls(opts={})
    controller_action = params[:action].to_s
    controller_action = "edit" if params[:action] == "destroy" 
    delegate_method = "enforce_#{controller_action}_permissions"
    if self.respond_to?(delegate_method.to_sym, true)
      self.send(delegate_method.to_sym)
    else
      true
    end
  end
  
  
  #
  #  Solr integration
  #
  
  # returns a params hash with the permissions info for a single solr document 
  # If the id arg is nil, then the value is fetched from params[:id]
  # This method is primary called by the get_permissions_solr_response_for_doc_id method.
  # Modeled on Blacklight::SolrHelper.solr_doc_params
  # @param [String] id of the documetn to retrieve
  def permissions_solr_doc_params(id=nil)
    id ||= params[:id]
    # just to be consistent with the other solr param methods:
    {
      :qt => :permissions,
      :id => id # this assumes the document request handler will map the 'id' param to the unique key field
    }
  end
  
  # a solr query method
  # retrieve a solr document, given the doc id
  # Modeled on Blacklight::SolrHelper.get_permissions_solr_response_for_doc_id
  # @param [String] id of the documetn to retrieve
  # @param [Hash] extra_controller_params (optional)
  def get_permissions_solr_response_for_doc_id(id=nil, extra_controller_params={})
    raise Blacklight::Exceptions::InvalidSolrID.new("The application is trying to retrieve permissions without specifying an asset id") if id.nil?
    solr_response = Blacklight.solr.find permissions_solr_doc_params(id).merge(extra_controller_params)
    raise Blacklight::Exceptions::InvalidSolrID.new("The solr permissions search handler didn't return anything for id \"#{id}\"") if solr_response.docs.empty?
    document = SolrDocument.new(solr_response.docs.first, solr_response)
    [solr_response, document]
  end
  
  # Loads permissions info into @permissions_solr_response and @permissions_solr_document
  def load_permissions_from_solr(id=params[:id], extra_controller_params={})
    unless !@permissions_solr_document.nil? && !@permissions_solr_response.nil?
      @permissions_solr_response, @permissions_solr_document = get_permissions_solr_response_for_doc_id(id, extra_controller_params)
    end
  end
  
  private

  # If someone hits the show action while their session's viewing_context is in edit mode, 
  # this will redirect them to the edit action.
  # If they do not have sufficient privileges to edit documents, it will silently switch their session to browse mode.
  def enforce_viewing_context_for_show_requests
    if params[:viewing_context] == "browse"
      session[:viewing_context] = params[:viewing_context]
    elsif session[:viewing_context] == "edit"
      if can? :edit, params[:id]
        logger.debug("enforce_viewing_context_for_show_requests redirecting to edit")
        if params[:files]
          redirect_to :action=>:edit, :files=>true
        else
          redirect_to :action=>:edit
        end
      else
        session[:viewing_context] = "browse"
      end
    end
  end
  
  #
  # Action-specific enforcement
  #
  
  # Controller "before" filter for enforcing access controls on show actions
  # @param [Hash] opts (optional, not currently used)
  def enforce_show_permissions(opts={})
    load_permissions_from_solr
    unless @permissions_solr_document['access_t'] && (@permissions_solr_document['access_t'].first == "public" || @permissions_solr_document['access_t'].first == "Public")
      if @permissions_solr_document["embargo_release_date_dt"] 
        embargo_date = Date.parse(@permissions_solr_document["embargo_release_date_dt"].split(/T/)[0])
        if embargo_date > Date.parse(Time.now.to_s)
          # check for depositor raise "#{@document["depositor_t"].first} --- #{user_key}"
          ### Assuming we're using devise and have only one authentication key
          unless current_user && user_key == @permissions_solr_document["depositor_t"].first
            flash[:notice] = "This item is under embargo.  You do not have sufficient access privileges to read this document."
            redirect_to(:action=>'index', :q=>nil, :f=>nil) and return false
          end
        end
      end
      unless can? :read, params[:id] 
        flash[:notice]= "You do not have sufficient access privileges to read this document, which has been marked private."
        redirect_to(:action => 'index', :q => nil , :f => nil) and return false
      end
    end
  end
  
  # Controller "before" filter for enforcing access controls on edit actions
  # @param [Hash] opts (optional, not currently used)
  def enforce_edit_permissions(opts={})
    logger.debug("Enforcing edit permissions")
    load_permissions_from_solr
    if !can? :edit, params[:id]
      session[:viewing_context] = "browse"
      flash[:notice] = "You do not have sufficient privileges to edit this document. You have been redirected to the read-only view."
      redirect_to :action=>:show
    else
      session[:viewing_context] = "edit"
    end
  end

  ## proxies to enforce_edit_permssions.  This method is here for you to override
  def enforce_update_permissions(opts={})
    enforce_edit_permissions(opts)
  end

  ## proxies to enforce_edit_permssions.  This method is here for you to override
  def enforce_delete_permissions(opts={})
    enforce_edit_permissions(opts)
  end

  # Controller "before" filter for enforcing access controls on index actions
  # Currently does nothing, instead relies on 
  # @param [Hash] opts (optional, not currently used)
  def enforce_index_permissions(opts={})
    return true
    # Do nothing. Relies on enforce_search_permissions being included in the Controller's solr_search_params_logic
    # apply_gated_discovery
    # if !reader? 
    #   solr_parameters[:qt] = Blacklight.config[:public_qt]
    # end
  end
  
  #
  # Solr query modifications
  #
  
  # Set solr_parameters to enforce appropriate permissions 
  # * Applies a lucene query to the solr :q parameter for gated discovery
  # * Uses public_qt search handler if user does not have "read" permissions
  # @param solr_parameters the current solr parameters
  # @param user_parameters the current user-subitted parameters
  #
  # @example This method should be added to your Catalog Controller's solr_search_params_logic
  #   class CatalogController < ApplicationController 
  #     include Hydra::Catalog
  #     CatalogController.solr_search_params_logic << :add_access_controls_to_solr_params
  #   end
  def add_access_controls_to_solr_params(solr_parameters, user_parameters)
    apply_gated_discovery(solr_parameters, user_parameters)
    if !can? :read, params[:id]
      solr_parameters[:qt] = Blacklight.config[:public_qt]
    end
  end
  
  # Contrller before filter that sets up access-controlled lucene query in order to provide gated discovery behavior
  # @param solr_parameters the current solr parameters
  # @param user_parameters the current user-subitted parameters
  def apply_gated_discovery(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    # Grant access to public content
    permission_types = ["edit","discover","read"]
    user_access_filters = []
    
    permission_types.each do |type|
      user_access_filters << "#{type}_access_group_t:public"
    end
    
    # Grant access based on user id & role
    unless current_user.nil?
      # for roles
      RoleMapper.roles(user_key).each_with_index do |role, i|
        permission_types.each do |type|
          user_access_filters << "#{type}_access_group_t:#{role}"
        end
      end
      # for individual person access
      permission_types.each do |type|
        user_access_filters << "#{type}_access_person_t:#{user_key}"        
      end
      if current_user.is_being_superuser?(session)
        permission_types.each do |type|
          user_access_filters << "#{type}_access_person_t:[* TO *]"        
        end
      end
      
      # Enforcing Embargo at Query time has been disabled.  
      # If you want to do this, set up your own solr_search_params before_filter that injects the appropriate :fq constraints for a field that expresses your objects' embargo status.
      #
      # include docs in results if the embargo date is NOT in the future OR if the current user is depositor
      # embargo_query = "(NOT embargo_release_date_dt:[NOW TO *]) OR depositor_t:#{user_key}"
      # embargo_query = "(NOT embargo_release_date_dt:[NOW TO *]) OR (embargo_release_date_dt:[NOW TO *] AND  depositor_t:#{user_key}) AND NOT (NOT depositor_t:#{user_key} AND embargo_release_date_dt:[NOW TO *])"
      # solr_parameters[:fq] << embargo_query         
    end
    solr_parameters[:fq] << user_access_filters.join(" OR ")
    logger.debug("Solr parameters: #{ solr_parameters.inspect }")
  end
  
  
  # proxy for {enforce_index_permissions}
  def enforce_search_permissions
    enforce_index_permissions
  end

  # proxy for {enforce_show_permissions}
  def enforce_read_permissions
    enforce_show_permissions
  end
  
  # This filters out objects that you want to exclude from search results.  By default it only excludes FileAssets
  # @param solr_parameters the current solr parameters
  # @param user_parameters the current user-subitted parameters
  def exclude_unwanted_models(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "-has_model_s:\"info:fedora/afmodel:FileAsset\""
  end

  # Build the lucene query that performs gated discovery based on Hydra rightsMetadata information in Solr
  # @param [String] user_query the user's original query request that will be wrapped in access controls
  def build_lucene_query(user_query)
    logger.warn("DEPRECATED: build_lucene_query has been deprecated.  Recommended convention is to use blacklight's dismax search requestHandler (not lucene) and filter queries with :fq solr parameters.  See Hydra::AccessControlsEnforcement#apply_gated_discovery and Hydra::AccessControlsEnforcement#exclude_unwanted_models")
    q = ""
    # start query of with user supplied query term
      q << "_query_:\"{!dismax qf=$qf_dismax pf=$pf_dismax}#{user_query}\" AND " if user_query


    # Append the exclusion of FileAssets
      q << "NOT _query_:\"info\\\\:fedora/afmodel\\\\:FileAsset\""

    # Append the query responsible for adding the users discovery level
      permission_types = ["edit","discover","read"]
      field_queries = []
      embargo_query = ""
      permission_types.each do |type|
        field_queries << "_query_:\"#{type}_access_group_t:public\""
      end

      unless current_user.nil?
        # for roles
        RoleMapper.roles(user_key).each do |role|
          permission_types.each do |type|
            field_queries << "_query_:\"#{type}_access_group_t:#{role}\""
          end
        end
        # for individual person access
        permission_types.each do |type|
          field_queries << "_query_:\"#{type}_access_person_t:#{user_key}\""
        end
        if current_user.is_being_superuser?(session)
          permission_types.each do |type|
            field_queries << "_query_:\"#{type}_access_person_t:[* TO *]\""
          end
        end

        # if it is the depositor and it is under embargo, that is ok
        # otherwise if it not the depositor and it is under embargo, don't show it
        embargo_query = " OR  ((_query_:\"embargo_release_date_dt:[NOW TO *]\" AND  _query_:\"depositor_t:#{user_key}\") AND NOT (NOT _query_:\"depositor_t:#{user_key}\" AND _query_:\"embargo_release_date_dt:[NOW TO *]\"))"
      end
      
      # remove anything with an embargo release date in the future  
#embargo_query = " AND NOT _query_:\"embargo_release_date_dt:[NOW TO *]\"" if embargo_query.blank?
      field_queries << " NOT _query_:\"embargo_release_date_dt:[NOW TO *]\"" if embargo_query.blank?
      
      q << " AND (#{field_queries.join(" OR ")})"
      q << embargo_query 
    return q
  end


end
