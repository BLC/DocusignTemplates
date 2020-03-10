module DocusignTemplates
  RSpec.describe Recipient do
    def make_tabs(type)
      10.times.map do |index|
        {
          tab_type: type,
          tab_label: "#{type}.example.#{index}"
        }
      end
    end

    let(:pdf_fields) do
      {
        text_tabs: make_tabs("text"),
        checkbox_tabs: make_tabs("checkbox")
      }
    end

    let(:tabs) do
      {
        sign_here_tabs: make_tabs("signature"),
        initial_here_tabs: make_tabs("initial")
      }
    end

    let(:data) do
      {
        recipient_id: "42",
        deep: {
          key: "derp"
        },
        pdf_fields: pdf_fields,
        tabs: tabs
      }
    end

    let(:template) { instance_double(Template) }

    let(:recipient) { Recipient.new(data, template) }

    describe "initialize" do
      it "sets the template" do
        expect(recipient.template).to be(template)
      end

      it "sets data to a deep copy of data without tabs or pdf_fields" do
        original = data[:deep][:key]
        expect(recipient.data).to eq(data.except(:pdf_fields, :tabs))

        recipient.data[:deep][:key] = "changed"
        expect(data[:deep][:key]).to eq(original)
      end

      it "creates field models for every pdf field on data" do
        data[:pdf_fields].each do |type, type_fields|
          expect(recipient.fields[type]).to be_a(Array)

          type_fields.each_with_index do |raw_field, index|
            match = recipient.fields[type][index]
            expect(match).to be_a(Field)
            expect(match.data).to eq(raw_field)
          end
        end
      end

      it "creates field models for every tab on data" do
        data[:tabs].each do |type, type_fields|
          expect(recipient.tabs[type]).to be_a(Array)

          type_fields.each_with_index do |raw_field, index|
            match = recipient.tabs[type][index]
            expect(match).to be_a(Field)
            expect(match.data).to eq(raw_field)
          end
        end
      end
    end

    describe "merge!" do
      it "merges the hash into the data" do
        original = recipient.data.deep_dup

        hash = { some: "extra", keys: "yep" }
        recipient.merge!(hash)

        expect(recipient.data).to eq(
          original.merge(hash)
        )
      end
    end

    describe "as_composite_template_entry" do
      before do
        allow_any_instance_of(Field).to receive(:document_id).and_return("42")
      end

      it "includes non-disabled tabs on the data" do
        recipient.tabs.values.flatten.each_with_index do |tab, index|
          tab.disabled = index.odd?
        end

        recipient.fields.values.flatten.each_with_index do |tab, index|
          tab.disabled = index.odd?
          tab.uploadable = index % 3 == 0
        end

        expected_tabs = {}.tap do |result|
          recipient.tabs.each do |type, type_tabs|
            result[type] = type_tabs.reject(&:disabled?).map(&:as_composite_template_entry)
          end

          recipient.fields.each do |type, type_fields|
            result[type] = type_fields
              .reject(&:disabled?)
              .select(&:uploadable?)
              .map(&:as_composite_template_entry)
          end
        end

        expect(recipient.as_composite_template_entry).to eq(
          recipient.data.merge(tabs: expected_tabs)
        )
      end
    end

    describe "role_name" do
      it "defers to the role_name in data" do
        role_name = "role name"
        data[:role_name] = role_name
        expect(recipient.role_name).to eq(role_name)
      end
    end

    describe "fields_for_document" do
      let(:document_id) { "42" }
      let(:document) { instance_double(Document, original_document_id: document_id, document_id: document_id) }
      let(:zero_document) { instance_double(Document, original_document_id: "0", document_id: "0") }

      before do
        allow(template).to receive(:documents).and_return([document, zero_document])
      end

      it "returns all fields for the document" do
        expected_fields = [].tap do |result|
          recipient.fields.values.flatten.each_with_index do |field, index|
            field.data[:document_id] = index.odd? ? document_id : "0"
            result << field if index.odd?
          end
        end

        expect(recipient.fields_for_document(document)).to eq(expected_fields)
      end
    end

    describe "tabs_for_document" do
      let(:document_id) { "42" }
      let(:document) { instance_double(Document, original_document_id: document_id, document_id: document_id) }
      let(:zero_document) { instance_double(Document, original_document_id: "0", document_id: "0") }

      before do
        allow(template).to receive(:documents).and_return([document, zero_document])
      end

      it "returns all tabs for the document" do
        expected_tabs = [].tap do |result|
          recipient.tabs.values.flatten.each_with_index do |tab, index|
            tab.data[:document_id] = index.odd? ? document_id : "0"
            result << tab if index.odd?
          end
        end

        expect(recipient.tabs_for_document(document)).to eq(expected_tabs)
      end
    end
  end
end
