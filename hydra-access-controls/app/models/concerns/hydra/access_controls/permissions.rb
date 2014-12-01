module Hydra
  module AccessControls
    module Permissions
      extend ActiveSupport::Concern
      include Hydra::AccessControls::Visibility

      included do
        has_many :permissions, predicate: ::ACL.accessTo, class_name: 'Hydra::AccessControls::Permission', inverse_of: :access_to
        accepts_nested_attributes_for :permissions, allow_destroy: true
        alias_method :permissions_attributes_without_uniqueness=, :permissions_attributes=
        alias_method :permissions_attributes=, :permissions_attributes_with_uniqueness=
      end

      def to_solr(solr_doc = {})
        super.tap do |doc|
          [:discover, :read, :edit].each do |access|
            vals = send("#{access}_groups")
            doc[Hydra.config.permissions[access].group] = vals unless vals.empty?
            vals = send("#{access}_users")
            doc[Hydra.config.permissions[access].individual] = vals unless vals.empty?
          end
        end
      end

      # When chaging a permission for an object/user, ensure an update is done, not a duplicate
      def permissions_attributes_with_uniqueness=(attributes_collection)
        if attributes_collection.is_a? Hash
          keys = attributes_collection.keys
          attributes_collection = if keys.include?('id') || keys.include?(:id)
            Array(attributes_collection)
          else
            attributes_collection.sort_by { |i, _| i.to_i }.map { |_, attributes| attributes }
          end
        end

        attributes_collection.each do |prop|
          existing = case prop[:type]
          when 'group'
            search_by_type(:group)
          when 'person'
            search_by_type(:person)
          end

          next unless existing
          selected = existing.find { |perm| perm.agent_name == prop[:name] }
          prop['id'] = selected.id if selected
        end

        self.permissions_attributes_without_uniqueness=attributes_collection
      end


      # Return a list of groups that have discover permission
      def discover_groups
        search_by_type_and_mode(:group, Hydra::ACL.Discover).map { |p| p.agent_name }
      end

      # Grant discover permissions to the groups specified. Revokes discover permission for all other groups.
      # @param[Array] groups a list of group names
      # @example
      #  r.discover_groups= ['one', 'two', 'three']
      #  r.discover_groups
      #  => ['one', 'two', 'three']
      #
      def discover_groups=(groups)
        set_discover_groups(groups, discover_groups)
      end

      # Grant discover permissions to the groups specified. Revokes discover permission for all other groups.
      # @param[String] groups a list of group names
      # @example
      #  r.discover_groups_string= 'one, two, three'
      #  r.discover_groups
      #  => ['one', 'two', 'three']
      #
      def discover_groups_string=(groups)
        self.discover_groups=groups.split(/[\s,]+/)
      end

      # Display the groups a comma delimeted string
      def discover_groups_string
        self.discover_groups.join(', ')
      end

      # Grant discover permissions to the groups specified. Revokes discover permission for
      # any of the eligible_groups that are not in groups.
      # This may be used when different users are responsible for setting different
      # groups.  Supply the groups the current user is responsible for as the
      # 'eligible_groups'
      # @param[Array] groups a list of groups
      # @param[Array] eligible_groups the groups that are eligible to have their discover permssion revoked.
      # @example
      #  r.discover_groups = ['one', 'two', 'three']
      #  r.discover_groups
      #  => ['one', 'two', 'three']
      #  r.set_discover_groups(['one'], ['three'])
      #  r.discover_groups
      #  => ['one', 'two']  ## 'two' was not eligible to be removed
      #
      def set_discover_groups(groups, eligible_groups)
        set_entities(:discover, :group, groups, eligible_groups)
      end

      def discover_users
        search_by_type_and_mode(:person, Hydra::ACL.Discover).map { |p| p.agent_name }
      end

      # Grant discover permissions to the users specified. Revokes discover permission for all other users.
      # @param[Array] users a list of usernames
      # @example
      #  r.discover_users= ['one', 'two', 'three']
      #  r.discover_users
      #  => ['one', 'two', 'three']
      #
      def discover_users=(users)
        set_discover_users(users, discover_users)
      end

      # Grant discover permissions to the groups specified. Revokes discover permission for all other users.
      # @param[String] users a list of usernames
      # @example
      #  r.discover_users_string= 'one, two, three'
      #  r.discover_users
      #  => ['one', 'two', 'three']
      #
      def discover_users_string=(users)
        self.discover_users=users.split(/[\s,]+/)
      end

      # Display the users as a comma delimeted string
      def discover_users_string
        self.discover_users.join(', ')
      end

      # Grant discover permissions to the users specified. Revokes discover permission for
      # any of the eligible_users that are not in users.
      # This may be used when different users are responsible for setting different
      # users.  Supply the users the current user is responsible for as the
      # 'eligible_users'
      # @param[Array] users a list of users
      # @param[Array] eligible_users the users that are eligible to have their discover permssion revoked.
      # @example
      #  r.discover_users = ['one', 'two', 'three']
      #  r.discover_users
      #  => ['one', 'two', 'three']
      #  r.set_discover_users(['one'], ['three'])
      #  r.discover_users
      #  => ['one', 'two']  ## 'two' was not eligible to be removed
      #
      def set_discover_users(users, eligible_users)
        set_entities(:discover, :person, users, eligible_users)
      end

      # Return a list of groups that have discover permission
      def read_groups
        search_by_type_and_mode(:group, ::ACL.Read).map { |p| p.agent_name }
      end

      # Grant read permissions to the groups specified. Revokes read permission for all other groups.
      # @param[Array] groups a list of group names
      # @example
      #  r.read_groups= ['one', 'two', 'three']
      #  r.read_groups
      #  => ['one', 'two', 'three']
      #
      def read_groups=(groups)
        set_read_groups(groups, read_groups)
      end

      # Grant read permissions to the groups specified. Revokes read permission for all other groups.
      # @param[String] groups a list of group names
      # @example
      #  r.read_groups_string= 'one, two, three'
      #  r.read_groups
      #  => ['one', 'two', 'three']
      #
      def read_groups_string=(groups)
        self.read_groups=groups.split(/[\s,]+/)
      end

      # Display the groups a comma delimeted string
      def read_groups_string
        self.read_groups.join(', ')
      end

      # Grant read permissions to the groups specified. Revokes read permission for
      # any of the eligible_groups that are not in groups.
      # This may be used when different users are responsible for setting different
      # groups.  Supply the groups the current user is responsible for as the
      # 'eligible_groups'
      # @param[Array] groups a list of groups
      # @param[Array] eligible_groups the groups that are eligible to have their read permssion revoked.
      # @example
      #  r.read_groups = ['one', 'two', 'three']
      #  r.read_groups
      #  => ['one', 'two', 'three']
      #  r.set_read_groups(['one'], ['three'])
      #  r.read_groups
      #  => ['one', 'two']  ## 'two' was not eligible to be removed
      #
      def set_read_groups(groups, eligible_groups)
        set_entities(:read, :group, groups, eligible_groups)
      end

      def read_users
        search_by_type_and_mode(:person, ::ACL.Read).map { |p| p.agent_name }
      end

      # Grant read permissions to the users specified. Revokes read permission for all other users.
      # @param[Array] users a list of usernames
      # @example
      #  r.read_users= ['one', 'two', 'three']
      #  r.read_users
      #  => ['one', 'two', 'three']
      #
      def read_users=(users)
        set_read_users(users, read_users)
      end

      # Grant read permissions to the groups specified. Revokes read permission for all other users.
      # @param[String] users a list of usernames
      # @example
      #  r.read_users_string= 'one, two, three'
      #  r.read_users
      #  => ['one', 'two', 'three']
      #
      def read_users_string=(users)
        self.read_users=users.split(/[\s,]+/)
      end

      # Display the users as a comma delimeted string
      def read_users_string
        self.read_users.join(', ')
      end

      # Grant read permissions to the users specified. Revokes read permission for
      # any of the eligible_users that are not in users.
      # This may be used when different users are responsible for setting different
      # users.  Supply the users the current user is responsible for as the
      # 'eligible_users'
      # @param[Array] users a list of users
      # @param[Array] eligible_users the users that are eligible to have their read permssion revoked.
      # @example
      #  r.read_users = ['one', 'two', 'three']
      #  r.read_users
      #  => ['one', 'two', 'three']
      #  r.set_read_users(['one'], ['three'])
      #  r.read_users
      #  => ['one', 'two']  ## 'two' was not eligible to be removed
      #
      def set_read_users(users, eligible_users)
        set_entities(:read, :person, users, eligible_users)
      end


      # Return a list of groups that have edit permission
      def edit_groups
        search_by_type_and_mode(:group, ::ACL.Write).map { |p| p.agent_name }
      end

      # Grant edit permissions to the groups specified. Revokes edit permission for all other groups.
      # @param[Array] groups a list of group names
      # @example
      #  r.edit_groups= ['one', 'two', 'three']
      #  r.edit_groups
      #  => ['one', 'two', 'three']
      #
      def edit_groups=(groups)
        set_edit_groups(groups, edit_groups)
      end

      # Grant edit permissions to the groups specified. Revokes edit permission for all other groups.
      # @param[String] groups a list of group names
      # @example
      #  r.edit_groups_string= 'one, two, three'
      #  r.edit_groups
      #  => ['one', 'two', 'three']
      #
      def edit_groups_string=(groups)
        self.edit_groups=groups.split(/[\s,]+/)
      end

      # Display the groups a comma delimeted string
      def edit_groups_string
        self.edit_groups.join(', ')
      end

      # Grant edit permissions to the groups specified. Revokes edit permission for
      # any of the eligible_groups that are not in groups.
      # This may be used when different users are responsible for setting different
      # groups.  Supply the groups the current user is responsible for as the
      # 'eligible_groups'
      # @param[Array] groups a list of groups
      # @param[Array] eligible_groups the groups that are eligible to have their edit permssion revoked.
      # @example
      #  r.edit_groups = ['one', 'two', 'three']
      #  r.edit_groups
      #  => ['one', 'two', 'three']
      #  r.set_edit_groups(['one'], ['three'])
      #  r.edit_groups
      #  => ['one', 'two']  ## 'two' was not eligible to be removed
      #
      def set_edit_groups(groups, eligible_groups)
        set_entities(:edit, :group, groups, eligible_groups)
      end

      def edit_users
        search_by_type_and_mode(:person, ::ACL.Write).map { |p| p.agent_name }
      end

      # Grant edit permissions to the groups specified. Revokes edit permission for all other groups.
      # @param[Array] users a list of usernames
      # @example
      #  r.edit_users= ['one', 'two', 'three']
      #  r.edit_users
      #  => ['one', 'two', 'three']
      #
      def edit_users=(users)
        set_edit_users(users, edit_users)
      end

      # Grant edit permissions to the users specified. Revokes edit permission for
      # any of the eligible_users that are not in users.
      # This may be used when different users are responsible for setting different
      # users.  Supply the users the current user is responsible for as the
      # 'eligible_users'
      # @param[Array] users a list of users
      # @param[Array] eligible_users the users that are eligible to have their edit permssion revoked.
      # @example
      #  r.edit_users = ['one', 'two', 'three']
      #  r.edit_users
      #  => ['one', 'two', 'three']
      #  r.set_edit_users(['one'], ['three'])
      #  r.edit_users
      #  => ['one', 'two']  ## 'two' was not eligible to be removed
      #
      def set_edit_users(users, eligible_users)
        set_entities(:edit, :person, users, eligible_users)
      end

      protected

      def has_destroy_flag?(hash)
        ["1", "true"].include?(hash['_destroy'].to_s)
      end

      private

      # @param [Symbol] permission either :discover, :read or :edit
      # @param [Symbol] type either :person or :group
      # @param [Array<String>] values Values to set
      # @param [Array<String>] changeable Values we are allowed to change
      def set_entities(permission, type, values, changeable)
        (changeable - values).each do |entity|
          for_destroy = search_by_type_and_mode(type, permission_to_uri(permission)).select { |p| p.agent_name == entity }
          permissions.delete(for_destroy)
        end

        values.each do |agent_name|
          exists = search_by_type_and_mode(type, permission_to_uri(permission)).select { |p| p.agent_name == agent_name }
          permissions.build(name: agent_name, access: permission.to_s, type: type ) unless exists.present?
        end
      end

      def permission_to_uri(permission)
        case permission.to_s
        when 'read'
          ::ACL.Read
        when 'edit'
          ::ACL.Write
        when 'discover'
          Hydra::ACL.Discover
        else
          raise "Invalid permission #{permission.inspect}"
        end
      end

      # @param [Symbol] type (either :group or :person)
      # @return [Array<Permission>]
      def search_by_type(type)
        case type
        when :group
          permissions.to_a.select { |p| group_agent?(p.agent) }
        when :person
          permissions.to_a.select { |p| person_agent?(p.agent) }
        end
      end

      # @param [Symbol] type either :group or :person
      # @param [::RDF::URI] mode One of the permissions modes, e.g. ACL.Write, ACL.Read, etc.
      # @return [Array<Permission>]
      def search_by_type_and_mode(type, mode)
        case type
        when :group
          permissions.to_a.select { |p| group_agent?(p.agent) && p.mode.first.rdf_subject == mode }
        when :person
          permissions.to_a.select { |p| person_agent?(p.agent) && p.mode.first.rdf_subject == mode }
        end
      end

      def person_permissions
        search_by_type(:person)
      end

      def group_permissions
        search_by_type(:group)
      end

      def group_agent?(agent)
        raise "no agent" unless agent.present?
        agent.first.rdf_subject.to_s.start_with?(GROUP_AGENT_URL_PREFIX)

      end

      def person_agent?(agent)
        raise "no agent" unless agent.present?
        agent.first.rdf_subject.to_s.start_with?(PERSON_AGENT_URL_PREFIX)
      end

    end
  end
end
