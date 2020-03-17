module DocusignTemplates
  RSpec.describe Document do
    let(:path) { "path/to/file.pdf" }

    let(:data) do
      {
        document_id: "123",
        deep: {
          key: "derp"
        },
        path: path
      }
    end

    let(:base_directory) { "some/directory" }

    let(:document) { Document.new(data, base_directory) }

    let(:recipient) { instance_double(Recipient) }
    let(:recipients) { [recipient] }

    describe ".unique_document_id" do
      it "returns a different id each time" do
        first = Document.unique_document_id
        second = Document.unique_document_id
        third = Document.unique_document_id

        expect(second).to eq(first + 1)
        expect(third).to eq(second + 1)
      end

      it "cycles after 999 to 1" do
        Document.instance_variable_set(:@last_id, 999)
        expect(Document.unique_document_id).to eq(999)
        expect(Document.unique_document_id).to eq(1)
      end
    end

    describe "initialize" do
      it "deep duplicates the data" do
        original = data[:deep][:key]
        expect(document.data).to eq(data)

        document.data[:deep][:key] = "changed"
        expect(data[:deep][:key]).to eq(original)
      end

      it "sets the base_directory" do
        expect(document.base_directory).to eq(base_directory)
      end

      it "sets the document_id to a unique id" do
        id = 32433232132432
        allow(Document).to receive(:unique_document_id).and_return(id)
        instance = Document.new(data, base_directory)
        expect(instance.document_id).to eq(id)
      end
    end

    describe "merge!" do
      it "merges the hash into the data" do
        original = document.data.deep_dup

        hash = { some: "extra", keys: "yep" }
        document.merge!(hash)

        expect(document.data).to eq(
          original.merge(hash)
        )
      end
    end

    describe "as_composite_template_entry" do
      let(:pdf) { "some pdf yay" }

      before do
        allow(document).to receive(:to_pdf).and_return(pdf)
      end

      it "returns a properly formatted entry" do
        expect(document).to receive(:to_pdf).with(recipients)

        expect(document.as_composite_template_entry(recipients)).to eq(
          document.data.except(:path).merge(
            document_id: document.document_id,
            document_base64: Base64.encode64(pdf)
          )
        )
      end

      describe "when multipart is true in options" do
        it "returns a properly formatted entry without data" do
          expect(document).not_to receive(:to_pdf)

          expect(document.as_composite_template_entry(recipients, multipart: true)).to eq(
            document.data.except(:path).merge(
              document_id: document.document_id
            )
          )
        end
      end
    end

    describe "path" do
      it "combines the base directory with the configured path" do
        expect(document.path).to eq("#{base_directory}/#{path}")
      end
    end

    describe "original_document_id" do
      it "pulls the document_id from the data" do
        expect(document.original_document_id).to eq(data[:document_id])
      end
    end

    describe "fields_for_recipient" do
      it "delegates to recipient.fields_for_document for itself" do
        result = "result"
        expect(recipient).to receive(:fields_for_document).with(document).and_return(result)
        expect(document.fields_for_recipient(recipient)).to eq(result)
      end
    end

    describe "tabs_for_recipient" do
      it "delegates to recipient.tabs_for_document for itself" do
        result = "result"
        expect(recipient).to receive(:tabs_for_document).with(document).and_return(result)
        expect(document.tabs_for_recipient(recipient)).to eq(result)
      end
    end

    describe "blank_pdf_data" do
      let(:blank_data) { "blank data 010101010" }

      before do
        allow(File).to receive(:read).and_return(blank_data)
      end

      it "reads data from the path" do
        expect(File).to receive(:read).with(document.path)
        expect(document.blank_pdf_data).to eq(blank_data)
      end

      it "is memoized" do
        expect(document.blank_pdf_data).to be(document.blank_pdf_data)
      end
    end

    describe "is_static?" do
      let(:recipients) do
        [
          instance_double(Recipient),
          instance_double(Recipient)
        ]
      end

      it "is true if every recipient has no fields" do
        recipients.each do |recipient|
          allow(recipient)
            .to receive(:fields_for_document)
            .with(document)
            .and_return([])
        end

        expect(document.is_static?(recipients)).to be(true)
      end

      it "is false if a recipient has fields" do
        recipients.each do |recipient|
          allow(recipient)
            .to receive(:fields_for_document)
            .with(document)
            .and_return(["something"])
        end

        expect(document.is_static?(recipients)).to be(false)
      end
    end

    describe "to_pdf" do
      let(:blank_pdf_data) { "blank pdf data" }
      let(:written_data) { "written pdf data" }

      before do
        allow(document).to receive(:blank_pdf_data).and_return(blank_pdf_data)
        allow(PdfWriter).to receive(:apply_fields!).and_return(written_data)
      end

      it "returns blank pdf data if static" do
        expect(document).to receive(:is_static?).with(recipients).and_return(true)
        expect(document.to_pdf(recipients)).to eq(blank_pdf_data)
      end

      it "writes pdf fields if not static" do
        expect(document).to receive(:is_static?).with(recipients).and_return(false)
        expect(PdfWriter).to receive(:apply_fields!).with(document, recipients)
        expect(document.to_pdf(recipients)).to eq(written_data)
      end
    end

    describe "save_pdf!" do
      let(:file) do
        result = instance_double(File)
        allow(result).to receive(:write)
        result
      end

      let(:pdf_data) { "pdf data 01010101" }

      before do
        allow(File).to receive(:open).and_yield(file)
        allow(document).to receive(:to_pdf).and_return(pdf_data)
      end

      it "writes the pdf to the given path" do
        expect(File).to receive(:open).with(path, "wb")
        expect(file).to receive(:write).with(pdf_data)
        expect(document).to receive(:to_pdf).with(recipients)
        document.save_pdf!(path, recipients)
      end
    end
  end
end
