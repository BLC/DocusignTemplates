module DocusignTemplates
  class Document
    attr_reader :data, :base_directory, :document_id

    MUTEX = Mutex.new

    # Returns a thread-safe unique document ID, which overrides the one configured in the template.
    # This is necessary because multipart form uplaods require each doc to have a unique ID.
    def self.unique_document_id
      MUTEX.synchronize do
        @last_id ||= 1
        value = @last_id
        @last_id = [(@last_id + 1) % 1000, 1].max
        value
      end
    end

    def initialize(data, base_directory)
      @data = data.deep_dup
      @base_directory = base_directory
      @document_id = Document.unique_document_id
    end

    def merge!(other_data)
      data.merge!(other_data)
    end

    def as_composite_template_entry(recipients, options = {})
      additional_data = options[:multipart] ? {
        document_id: document_id
      } : {
        document_id: document_id,
        document_base64: Base64.encode64(to_pdf(recipients))
      }

      data.except(:path).merge(additional_data)
    end

    def path
      "#{base_directory}/#{data[:path]}"
    end

    # The original document_id from the template. This won't be used in `as_composite_template_entry`,
    # but it used to match recipient tabs to this document.
    def original_document_id
      data[:document_id]
    end

    def fields_for_recipient(recipient)
      recipient.fields_for_document(self)
    end

    def tabs_for_recipient(recipient)
      recipient.tabs_for_document(self)
    end

    def blank_pdf_data
      @blank_pdf_data ||= File.read(path)
    end

    def is_static?(recipients)
      recipients.all? do |recipient|
        # can use static PDF if only tabs
        fields_for_recipient(recipient).empty?
      end
    end

    def to_pdf(recipients)
      if is_static?(recipients)
        blank_pdf_data
      else
        apply_fields_to_pdf(recipients)
      end
    end

    def save_pdf!(path, recipients)
      File.open(path, "wb") do |file|
        file.write to_pdf(recipients)
      end
    end

    private

    def apply_fields_to_pdf(recipients)
      PdfWriter.apply_fields!(self, recipients)
    end
  end
end
