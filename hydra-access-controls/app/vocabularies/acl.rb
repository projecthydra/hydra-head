class ACL < RDF::StrictVocabulary('http://www.w3.org/ns/auth/acl#')
  property :access_to
  property :mode
  property :agent
  property :agentClass

  property :Agent
  property :Read
  property :Write
  property :Append
  property :Control
end
