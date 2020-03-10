module DocusignTemplates
  class Recipient
    attr_reader :data, :template, :fields, :tabs

    def initialize(data, template)
      @template = template
      @data = data.except(:tabs, :pdf_fields).deep_dup
      @fields = parse_fields_or_tabs(data[:pdf_fields])
      @tabs = parse_fields_or_tabs(data[:tabs])
    end

    def merge!(other_data)
      data.merge!(other_data)
    end

    def as_composite_template_entry
      data.merge(
        tabs: enabled_tabs_for_composite_entry
      )
    end

    def role_name
      data[:role_name]
    end

    def fields_for_document(document)
      flatten_fields(fields).select do |field|
        field.document_id == document.document_id
      end
    end

    def tabs_for_document(document)
      flatten_fields(tabs).select do |tab|
        tab.document_id == document.document_id
      end
    end

    private

    def enabled_tabs_for_composite_entry
      result = {}

      tabs.each do |type, type_tabs|
        enabled_tabs = type_tabs.reject(&:disabled?)

        next if enabled_tabs.empty?
        result[type] = enabled_tabs.map(&:as_composite_template_entry)
      end

      fields.each do |type, type_fields|
        uploadable_fields = type_fields.reject(&:disabled?).select(&:uploadable?)

        next if uploadable_fields.empty?
        result[type] = uploadable_fields.map(&:as_composite_template_entry)
      end

      result
    end

    def flatten_fields(fields)
      fields.values.flatten
    end

    def parse_fields_or_tabs(fields_or_tabs)
      result = {}

      fields_or_tabs.each do |type, type_fields|
        result[type] = type_fields.map do |field|
          Field.new(field, template)
        end
      end

      result
    end
  end
end
