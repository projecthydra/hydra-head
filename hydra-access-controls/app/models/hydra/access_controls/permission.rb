module Hydra::AccessControls
  class Permission < AccessControlList
    def initialize(args)
      super()
      build_agent(args[:name], args[:type].to_s)
      build_access(args[:access])
    end

    def to_hash
      { name: agent_name, type: type_from_agent, access: access_from_mode }
    end

    def inspect
      "<#{self.class.name} pid: #{pid} agent: #{agent.first.rdf_subject.to_s.inspect} mode: #{mode.first.rdf_subject.to_s.inspect} access_to: #{access_to_id.inspect}>"
    end

    def == other
      other.is_a?(Permission) && self.pid == self.pid && self.access_to_id == other.access_to_id &&
        self.agent.first.rdf_subject == other.agent.first.rdf_subject && self.mode.first.rdf_subject == other.mode.first.rdf_subject
    end

    def attributes=(attributes)
      attrs = attributes.dup
      name = attrs.delete(:name)
      type = attrs.delete(:type)
      build_agent(name, type) if name && type
      access = attrs.delete(:access)
      build_access(access) if access
      super(attrs)
    end

    def agent_name
      parsed_agent.last
    end

    protected

      def parsed_agent
        @parsed_agent ||= agent.first.rdf_subject.to_s.sub('http://projecthydra.org/ns/auth/', '').split('#')
      end

      def type_from_agent
        parsed_agent.first
      end

      def access_from_mode
        @access ||= mode.first.rdf_subject.to_s.split('#').last.downcase.sub('write', 'edit')
      end

      def build_agent(name, type)
        raise "Can't build agent #{inspect}" unless name && type
        self.agent = case type
                     when "group"
                       Agent.new(RDF::URI.new("http://projecthydra.org/ns/auth/group##{name}"))
                     when "person"
                       Agent.new(RDF::URI.new("http://projecthydra.org/ns/auth/person##{name}"))
                     when "user"
                       Deprecation.warn Permission, "Passing \"user\" as the type to Permission is deprecated. Use \"person\" instead. This will be an error in ActiveFedora 9."
                       Agent.new(RDF::URI.new("http://projecthydra.org/ns/auth/person##{name}"))
                     else
                       raise ArgumentError, "Unknown agent type #{type.inspect}"
                     end
      end

      def build_access(access)
        raise "Can't build access #{inspect}" unless access
        self.mode = case access
                    when "read"
                      Mode.new(::ACL.Read)
                    when "edit"
                      Mode.new(::ACL.Write)
                    when "discover"
                      Mode.new(Hydra::ACL.Discover)
                    else
                      raise ArgumentError, "Unknown access #{access.inspect}"
                    end
      end

  end
end
