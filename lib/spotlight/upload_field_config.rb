# frozen_string_literal: true

module Spotlight
  ##
  # A class to model the configuration required to build the Document Upload form.
  # This configuration is also used in other places around the application (e.g. Metadata Field Config)
  # See Spotlight::Engine.config.upload_fields for where this is consumed
  # We should look into changing this to a standard blacklight field config in Blacklight 7
  class UploadFieldConfig
    attr_reader :blacklight_options, :field_name, :form_field_type

    def initialize(field_name:, blacklight_options: {}, form_field_type: :text_field, label: nil, solr_fields: nil)
      @blacklight_options = blacklight_options
      @field_name = field_name
      @form_field_type = form_field_type
      @solr_fields = solr_fields
      @label = label || field_name
    end

    # Allows a proc to be set as the label
    def label
      return @label.call if @label.is_a?(Proc)

      @label
    end

    # aliasing for backwards compatability and consistency with blacklight config
    alias solr_field field_name

    # providing backwards compatibility with the old way of configuring upload fields
    def solr_fields
      @solr_fields || Array(solr_field || field_name)
    end

    def data_to_solr(value)
      solr_fields.each_with_object({}) do |solr_field, solr_hash|
        if solr_field.is_a? Hash
          solr_field.each do |name, lambda|
            solr_hash[name] = lambda.call(value)
          end
        else
          solr_hash[solr_field] = value
        end
      end
    end
  end
end
