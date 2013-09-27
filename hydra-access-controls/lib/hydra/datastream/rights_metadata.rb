require 'active_support/core_ext/string'
module Hydra
  module Datastream
    # Implements Hydra RightsMetadata XML terminology for asserting access permissions
    class RightsMetadata < ActiveFedora::OmDatastream       
      
      set_terminology do |t|
        t.root(:path=>"rightsMetadata", :xmlns=>"http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1", :schema=>"http://github.com/projecthydra/schemas/tree/v1/rightsMetadata.xsd") 
        t.copyright {
          ## BEGIN possible delete, justin 2012-06-22
          t.machine {
            t.cclicense   
            t.license     
          }
          t.human_readable(:path=>"human")
          t.license(:proxy=>[:machine, :license ])            
          t.cclicense(:proxy=>[:machine, :cclicense ])                  
          ## END possible delete

          t.title(:path=>'human', :attributes=>{:type=>'title'})
          t.description(:path=>'human', :attributes=>{:type=>'description'})
          t.url(:path=>'machine', :attributes=>{:type=>'uri'})
        }
        t.access do
          t.human_readable(:path=>"human")
          t.machine {
            t.group
            t.person
          }
          t.person(:proxy=>[:machine, :person])
          t.group(:proxy=>[:machine, :group])
          # accessor :access_person, :term=>[:access, :machine, :person]
        end
        t.discover_access(:ref=>[:access], :attributes=>{:type=>"discover"})
        t.read_access(:ref=>[:access], :attributes=>{:type=>"read"})
        t.edit_access(:ref=>[:access], :attributes=>{:type=>"edit"})
        # A bug in OM prevnts us from declaring proxy terms at the root of a Terminology
        # t.access_person(:proxy=>[:access,:machine,:person])
        # t.access_group(:proxy=>[:access,:machine,:group])
        
        t.embargo {
          t.human_readable(:path=>"human")
          t.machine{
            t.date(:type =>"release")
          }
          t.embargo_release_date(:proxy => [:machine, :date])
        }    

        t.license(:ref=>[:copyright])
      end

      # Generates an empty Mods Article (used when you call ModsArticle.new without passing in existing xml)
      def self.xml_template
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.rightsMetadata(:version=>"0.1", "xmlns"=>"http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1") {
            xml.copyright {
              xml.human(:type=>'title')
              xml.human(:type=>'description')
              xml.machine(:type=>'uri')
              
            }
            xml.access(:type=>"discover") {
              xml.human
              xml.machine
            }
            xml.access(:type=>"read") {
              xml.human 
              xml.machine
            }
            xml.access(:type=>"edit") {
              xml.human
              xml.machine
            }
            xml.embargo{
              xml.human
              xml.machine
            }        
          }
        end
        return builder.doc
      end
        
      # Returns the permissions for the selected person/group
      # If new_access_level is provided, updates the selected person/group access_level to the one specified 
      # A new_access_level of "none" will remove all access_levels for the selected person/group
      # @param [Hash] selector hash in format {type => identifier}
      # @param new_access_level (default nil)
      # @return Hash in format {type => access_level}.  
      # 
      # ie. 
      # permissions({:person=>"person123"})
      # => {"person123"=>"edit"}
      # permissions({:person=>"person123"}, "read")
      # => {"person123"=>"read"}
      # permissions({:person=>"person123"})
      # => {"person123"=>"read"}
      def permissions(selector, new_access_level=nil)
        type = selector.keys.first.to_sym
        actor = selector.values.first
        if new_access_level.nil?
          xpath = xpath(type, actor)
          nodeset = self.find_by_terms(xpath)
          if nodeset.empty?
            return "none"
          else
            return nodeset.first.ancestors("access").first.attributes["type"].text
          end
        else
          remove_all_permissions(selector)
          if new_access_level == "none" 
            self.content = self.to_xml
          else
            access_type_symbol = "#{new_access_level}_access".to_sym
            current_values = term_values(access_type_symbol, type)
            self.update_values([access_type_symbol, type] => current_values + [actor] )
          end
          return new_access_level
        end
          
      end
      
      # Reports on which groups have which permissions
      # @return Hash in format {group_name => group_permissions, group_name => group_permissions}
      def groups
        return quick_search_by_type(:group)
      end
      
      # Reports on which groups have which permissions
      # @return Hash in format {person_name => person_permissions, person_name => person_permissions}
      def individuals
        return quick_search_by_type(:person)
      end
      
      # Updates permissions for all of the persons and groups in a hash
      # @param params ex. {"group"=>{"group1"=>"discover","group2"=>"edit"}, "person"=>{"person1"=>"read","person2"=>"discover"}}
      # Currently restricts actor type to group or person.  Any others will be ignored
      def update_permissions(params)
        params.fetch("group", {}).each_pair {|group_id, access_level| self.permissions({"group"=>group_id}, access_level)}
        params.fetch("person", {}).each_pair {|person_id, access_level| self.permissions({"person"=>person_id}, access_level)}
      end

      # Updates all permissions
      # @param params ex. {"group"=>{"group1"=>"discover","group2"=>"edit"}, "person"=>{"person1"=>"read","person2"=>"discover"}}
      # Restricts actor type to group or person.  Any others will be ignored
      def permissions= (params)
        group_ids = groups.keys | params['group'].keys
        group_ids.each {|group_id| self.permissions({"group"=>group_id}, params['group'].fetch(group_id, 'none'))}
        user_ids = individuals.keys | params['person'].keys
        user_ids.each {|person_id| self.permissions({"person"=>person_id}, params['person'].fetch(person_id, 'none'))}
      end
      
      # @param [Symbol] type (either :group or :person)
      # @return 
      # This method limits the response to known access levels.  Probably runs a bit faster than .permissions().
      def quick_search_by_type(type)
        result = {}
        [{:discover_access=>"discover"},{:read_access=>"read"},{:edit_access=>"edit"}].each do |access_levels_hash|
          access_level = access_levels_hash.keys.first
          access_level_name = access_levels_hash.values.first
          self.find_by_terms(*[access_level, type]).each do |entry|
            result[entry.text] = access_level_name
          end
        end
        return result
      end

      attr_reader :embargo_release_date
      def embargo_release_date=(release_date)
        release_date = release_date.to_s if release_date.is_a? Date
        begin
          Date.parse(release_date)
        rescue 
          return "INVALID DATE"
        end
        self.update_values({[:embargo,:machine,:date]=>release_date})
      end
      def embargo_release_date(opts={})
        embargo_release_date = self.find_by_terms(*[:embargo,:machine,:date]).first ? self.find_by_terms(*[:embargo,:machine,:date]).first.text : nil
        if embargo_release_date.present? && opts[:format] && opts[:format] == :solr_date
          embargo_release_date << "T23:59:59Z"
        end
        embargo_release_date
      end
      def under_embargo?
        (embargo_release_date && Date.today < embargo_release_date.to_date) ? true : false
      end

      def to_solr(solr_doc=Hash.new)
        super(solr_doc)
        vals = edit_access.machine.group
        solr_doc[ActiveFedora::SolrService.solr_name('edit_access_group', indexer)] = vals unless vals.empty?
        vals = discover_access.machine.group
        solr_doc[ActiveFedora::SolrService.solr_name('discover_access_group', indexer)] = vals unless vals.empty?
        vals = read_access.machine.group
        solr_doc[ActiveFedora::SolrService.solr_name('read_access_group', indexer)] = vals unless vals.empty?
        vals = edit_access.machine.person
        solr_doc[ActiveFedora::SolrService.solr_name('edit_access_person', indexer)] = vals unless vals.empty?
        vals = discover_access.machine.person
        solr_doc[ActiveFedora::SolrService.solr_name('discover_access_person', indexer)] = vals unless vals.empty?
        vals = read_access.machine.person
        solr_doc[ActiveFedora::SolrService.solr_name('read_access_person', indexer)] = vals unless vals.empty?

        if embargo_release_date
          embargo_release_date_solr_key_name = ActiveFedora::SolrService.solr_name("embargo_release_date", date_indexer)
          ::Solrizer::Extractor.insert_solr_field_value(solr_doc, embargo_release_date_solr_key_name , embargo_release_date(:format=>:solr_date))
        end
        solr_doc
      end

      def indexer
        self.class.indexer
      end

      def self.indexer
        @indexer ||= Solrizer::Descriptor.new(:string, :stored, :indexed, :multivalued)
      end

      def date_indexer
        self.class.date_indexer
      end

      def self.date_indexer
        @date_indexer ||= Solrizer::Descriptor.new(:date, :stored, :indexed)
      end

      # Completely clear the permissions
      def clear_permissions!
        remove_all_permissions({:person=>true})
        remove_all_permissions({:group=>true})
      end


      
      private
      # Purge all access given group/person 
      def remove_all_permissions(selector)
        return unless ng_xml
        type = selector.keys.first.to_sym
        actor = selector.values.first
        xpath = xpath(type, actor)
        nodes_to_purge = self.find_by_terms(xpath)
        nodes_to_purge.each {|node| node.remove}
      end

      # @param [Symbol] type (:group, :person)
      # @param [String,TrueClass] actor the user we want to find. If actor is true, then don't query.
      def xpath(type, actor)
        raise ArgumentError, "Type must either be ':group' or ':person'. You provided: '#{type.inspect}'" unless [:group, :person].include?(type)
        path = "//oxns:access/oxns:machine/oxns:#{type}"
        if actor.is_a? String
          clean_actor = actor.gsub("'", '')
          path += "[text() = '#{clean_actor}']" 
        end
        path
      end
      
    end
  end
end
