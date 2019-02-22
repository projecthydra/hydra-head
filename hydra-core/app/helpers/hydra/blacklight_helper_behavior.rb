# frozen_string_literal: true

module Hydra
  module BlacklightHelperBehavior
    include Blacklight::BlacklightHelperBehavior

    ##
    # Given a Fedora uri, generate a reasonable partial name
    # Rails thinks that periods indicate a filename, so escape them with slashes.
    #
    # @param [SolrDocument] document
    # @param [String, Array] display_type a value suggestive of a partial
    # @return [String] the name of the partial to render
    # @example
    #   type_field_to_partial_name(["GenericContent"])
    #   => 'generic_content'
    #   type_field_to_partial_name(["text.pdf"])
    #   => 'text_pdf'
    def type_field_to_partial_name(_document, display_type)
      str = Array(display_type).join(' ').underscore
      if Rails.version >= '5.0.0'
        str.parameterize(separator: '_')
      else
        str.parameterize('_')
      end
    end
  end
end
