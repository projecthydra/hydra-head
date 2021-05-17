class Hydra::PermissionsSolrDocument < SolrDocument
  def under_embargo?
    #permissions = permissions_doc(params[:id])
    embargo_key = Hydra.config.permissions.embargo.release_date
    if self[embargo_key]
      embargo_date = DateTime.parse(self[embargo_key])
      return embargo_date > DateTime.parse(Time.now.to_s)
    end
    false
  end
end
