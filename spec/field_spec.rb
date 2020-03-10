module DocusignTemplates
  RSpec.describe Field do
    let(:data) do
      {
        tab_label: "tab.label",
        deep: {
          key: "derp"
        }
      }
    end
    let(:template) { instance_double(Template) }
    let(:field) { Field.new(data, template) }
    let(:radio_field) { Field.new(data, template, true) }

    describe "initialize" do
      it "sets the template" do
        expect(field.template).to be(template)
      end

      it "deep duplicates the data" do
        original = data[:deep][:key]
        expect(field.data).to eq(data)

        field.data[:deep][:key] = "changed"
        expect(data[:deep][:key]).to eq(original)
      end

      it "defaults is_radio? and disabled? to false" do
        expect(field.is_radio?).to be(false)
        expect(field.disabled?).to be(false)
      end

      it "sets is_radio? to true if specified" do
        expect(radio_field.is_radio?).to be(true)
      end

      context "position correction" do
        let(:x) { 50 }
        let(:y) { 50 }

        before do
          data.merge!(x_position: x.to_s, y_position: y.to_s)
        end

        it "offsets a pdf field correctly" do
          data[:tab_type] = Field::FieldTypes::TEXT
          field = Field.new(data, template)

          expect(field.x).to eq(x + 3)
          expect(field.y).to eq(y + 1)
        end

        it "offsets a radio field correctly" do
          field = Field.new(data, template, true)

          expect(field.x).to eq(x + 3)
          expect(field.y).to eq(y + 1)
        end

        it "offsets a signature field correctly" do
          data[:tab_type] = Field::FieldTypes::SIGNATURE
          field = Field.new(data, template)

          expect(field.x).to eq(x)
          expect(field.y).to eq(y - 21)
        end

        it "does not offset other fields" do
          data[:tab_type] = "other"
          field = Field.new(data, template)

          expect(field.x).to eq(x)
          expect(field.y).to eq(y)
        end

        it "sets the @original_positions instance variable" do
          data[:tab_type] = Field::FieldTypes::TEXT
          field = Field.new(data, template)

          expect(field.instance_variable_get(:@original_positions)).to eq({
            x_position: x.to_s,
            y_position: y.to_s
          })
        end
      end
    end

    describe "as_composite_template_entry" do
      let(:original_positions) do
        {
          x_position: "123",
          y_position: "45"
        }
      end

      let(:data) do
        {
          tab_label: "tab.label",
          tab_type: Field::FieldTypes::TEXT
        }.merge(original_positions)
      end

      let(:document_id) { "42" }
      let(:base_data) { field.data.merge(document_id: document_id) }

      before do
        allow(field).to receive(:document_id).and_return(document_id)
      end

      context "when a radio group field" do
        let(:radios) do
          3.times.map do |index|
            Field.new(data.merge(value: "value_#{index}"), template, true)
          end
        end

        before do
          allow(field).to receive(:is_radio_group?).and_return(true)
          allow(field).to receive(:radios).and_return(radios)

          radios.each do |radio|
            allow(radio).to receive(:document_id).and_return(document_id)
          end
        end

        it "returns the data with serialized radios" do
          expect(field.as_composite_template_entry).to eq(
            base_data.merge(radios: radios.map(&:as_composite_template_entry))
          )
        end
      end

      context "when a list field" do
        let(:list_items) do
          3.times.map do |index|
            Field.new(data.merge(value: "value_#{index}"), template, true)
          end
        end

        before do
          allow(field).to receive(:is_list?).and_return(true)
          allow(field).to receive(:list_items).and_return(list_items)

          list_items.each do |list_item|
            allow(list_item).to receive(:document_id).and_return(document_id)
          end
        end

        it "returns the data with serialized list items" do
          expect(field.as_composite_template_entry).to eq(
            base_data.merge(original_positions).merge(
              list_items: list_items.map(&:as_composite_template_entry)
            )
          )
        end
      end

      context "when another type of pdf field" do
        it "returns the data merged with the original positions" do
          expect(field.as_composite_template_entry).to eq(base_data.merge(original_positions))
        end
      end

      context "when a radio" do
        before do
          allow(field).to receive(:is_radio?).and_return(true)
        end

        it "returns the data merged with the original positions" do
          expect(field.as_composite_template_entry).to eq(base_data.merge(original_positions))
        end
      end

      context "when not a pdf field" do
        before do
          allow(field).to receive(:is_pdf_field?).and_return(false)
        end

        it "returns the data" do
          expect(field.as_composite_template_entry).to eq(base_data)
        end
      end
    end

    describe "merge!" do
      it "merges the hash into the data" do
        original = field.data.deep_dup

        hash = { some: "extra", keys: "yep" }
        field.merge!(hash)

        expect(field.data).to eq(
          original.merge(hash)
        )
      end
    end

    describe "selected?" do
      it "returns true if selected" do
        data[:selected] = "true"
        expect(field.selected?).to be(true)
      end

      it "returns false if not selected" do
        data[:selected] = "false"
        expect(field.selected?).to be(false)
      end
    end

    describe "value" do
      context "when a checkbox" do
        before do
          allow(field).to receive(:is_checkbox?).and_return(true)
        end

        it "defers to selected?" do
          selected = "selected"
          expect(field).to receive(:selected?).and_return(selected)
          expect(field.value).to eq(selected)
        end
      end

      context "when a radio group" do
        before do
          allow(field).to receive(:is_radio_group?).and_return(true)
        end

        it "returns nil if there is no selected item" do
          expect(field).to receive(:selected_item).and_return(nil)
          expect(field.value).to be(nil)
        end

        it "returns the selected item value if present" do
          value = "value"
          selected_item = instance_double(Field, value: value)
          expect(field).to receive(:selected_item).and_return(selected_item)
          expect(field.value).to be(value)
        end
      end

      context "when a list" do
        before do
          allow(field).to receive(:is_list?).and_return(true)
        end

        it "returns nil if there is no selected item" do
          expect(field).to receive(:selected_item).and_return(nil)
          expect(field.value).to be(nil)
        end

        it "returns the selected item value if present" do
          value = "value"
          selected_item = instance_double(Field, value: value)
          expect(field).to receive(:selected_item).and_return(selected_item)
          expect(field.value).to be(value)
        end
      end

      context "when another type" do
        it "returns the value from data" do
          data[:value] = "value"
          expect(field.value).to eq(data[:value])
        end
      end
    end

    describe "value=" do
      context "when a checkbox" do
        before do
          allow(field).to receive(:is_checkbox?).and_return(true)
        end

        it "sets selected to the string version of the boolean" do
          field.value = true
          expect(field.data[:selected]).to eq("true")
        end
      end

      context "when a radio group" do
        let(:radios) do
          3.times.map do |index|
            Field.new(data.merge(value: "value_#{index}"), template, true)
          end
        end

        before do
          allow(field).to receive(:is_radio_group?).and_return(true)
          allow(field).to receive(:radios).and_return(radios)
        end

        it "selects the correct radio" do
          value = "value_1"
          field.value = value

          field.radios.each do |radio|
            expect(radio.data[:selected]).to eq((radio.value == value).to_s)
          end
        end
      end

      context "when a list" do
        let(:list_items) do
          3.times.map do |index|
            Field.new(data.merge(value: "value_#{index}"), template, true)
          end
        end

        before do
          allow(field).to receive(:is_list?).and_return(true)
          allow(field).to receive(:list_items).and_return(list_items)
        end

        it "selects the correct list item" do
          value = "value_1"
          field.value = value

          field.list_items.each do |list_item|
            expect(list_item.data[:selected]).to eq((list_item.value == value).to_s)
          end
        end
      end

      context "when another type" do
        it "sets the value in data" do
          value = "some value"
          field.value = value
          expect(field.data[:value]).to eq(value)
        end
      end
    end

    describe "disabled?" do
      it "returns disabled" do
        field.disabled = true
        expect(field.disabled?).to be(true)

        field.disabled = false
        expect(field.disabled?).to be(false)
      end
    end

    describe "uploadable?" do
      context "when a pdf field" do
        before do
          allow(field).to receive(:is_pdf_field?).and_return(true)
        end

        it "returns false by default" do
          expect(field.uploadable?).to be(false)
        end

        it "returns true if set to uploadable" do
          field.uploadable = true
          expect(field.uploadable?).to be(true)
        end
      end

      context "when a tab" do
        before do
          allow(field).to receive(:is_pdf_field?).and_return(false)
        end

        it "returns true" do
          expect(field.uploadable?).to be(true)
        end
      end
    end

    describe "uploadable=" do
      before do
        allow(field).to receive(:is_pdf_field?).and_return(true)
      end

      it "sets uploadable to the value" do
        field.uploadable = false
        expect(field.uploadable?).to be(false)

        field.uploadable = true
        expect(field.uploadable?).to be(true)
      end

      context "when a radio group" do
        let(:radios) do
          3.times.map do |index|
            Field.new(data.merge(value: "value_#{index}"), template, true)
          end
        end

        before do
          allow(field).to receive(:is_radio_group?).and_return(true)
          allow(field).to receive(:radios).and_return(radios)
        end

        it "sets locked in each radio to the value" do
          field.uploadable = false
          radios.each do |radio|
            expect(radio.data[:locked]).to eq(false.to_s)
          end

          field.uploadable = true
          radios.each do |radio|
            expect(radio.data[:locked]).to eq(true.to_s)
          end
        end
      end

      context "when not a radio group" do
        before do
          allow(field).to receive(:is_radio_group?).and_return(false)
        end

        it "sets locked in the field to the value" do
          field.uploadable = false
          expect(field.data[:locked]).to eq(false.to_s)

          field.uploadable = true
          expect(field.data[:locked]).to eq(true.to_s)
        end
      end
    end

    describe "label" do
      it "returns the group_name if present" do
        group_name = "group.name"
        data[:group_name] = group_name
        expect(field.label).to eq(group_name)
      end

      it "returns the tab_label if no group_name is present" do
        expect(field.label).to eq(data[:tab_label])
      end
    end

    describe "name" do
      it "returns the name if present" do
        name = "some name"
        data[:name] = name
        expect(field.name).to eq(name)
      end

      it "returns the text if no name is present" do
        text = "some text"
        data[:text] = text
        expect(field.name).to eq(text)
      end
    end

    describe "selected_item" do
      context "when a radio group" do
        let(:radios) do
          3.times.map do |index|
            Field.new(data.merge(value: "value_#{index}"), template, true)
          end
        end

        before do
          allow(field).to receive(:is_radio_group?).and_return(true)
          allow(field).to receive(:radios).and_return(radios)
          radios.last.data[:selected] = "true"
        end

        it "returns the selected radio" do
          expect(field.selected_item).to eq(radios.last)
        end
      end

      context "when a list" do
        let(:list_items) do
          3.times.map do |index|
            Field.new(data.merge(value: "value_#{index}"), template, true)
          end
        end

        before do
          allow(field).to receive(:is_list?).and_return(true)
          allow(field).to receive(:list_items).and_return(list_items)
          list_items.last.data[:selected] = "true"
        end

        it "returns the selected list item" do
          expect(field.selected_item).to eq(list_items.last)
        end
      end

      context "when another type" do
        it "returns nil" do
          expect(field.selected_item).to be(nil)
        end
      end
    end

    describe "x" do
      it "converts the x_position to an integer" do
        x = 123
        data[:x_position] = x.to_s
        expect(field.x).to eq(x)
      end
    end

    describe "y" do
      it "converts the y_position to an integer" do
        y = 123
        data[:y_position] = y.to_s
        expect(field.y).to eq(y)
      end
    end

    describe "width" do
      it "converts width to an integer if present" do
        width = 123
        data[:width] = width.to_s
        expect(field.width).to eq(width)
      end

      it "returns height if width is not present" do
        height = 42
        expect(field).to receive(:height).and_return(height)
        expect(field.width).to eq(height)
      end
    end

    describe "height" do
      it "converts the height to an integer" do
        height = 123
        data[:height] = height.to_s
        expect(field.height).to eq(height)
      end

      context "when the height is not present" do
        it "returns the font_size" do
          font_size = 12
          expect(field).to receive(:font_size).and_return(font_size)
          expect(field.height).to eq(font_size)
        end
      end
    end

    describe "font_color" do
      it "converts font_color to a symbol from data" do
        font_color = "green"
        data[:font_color] = font_color
        expect(field.font_color).to eq(font_color.to_sym)
      end

      it "returns black if not present on data" do
        expect(field.font_color).to eq(:black)
      end
    end

    describe "font_size" do
      it "converts font_size to an integer from data" do
        font_size = 27
        data[:font_size] = "size#{font_size}"
        expect(field.font_size).to eq(font_size)
      end

      it "returns 10 if not present on data" do
        expect(field.font_size).to eq(10)
      end
    end

    describe "recipient_id" do
      it "returns the recipient_id from data" do
        recipient_id = "123"
        data[:recipient_id] = recipient_id
        expect(field.recipient_id).to eq(recipient_id)
      end
    end

    describe "document" do
      let(:original_document_id) { "42" }
      let(:matching_document) do
        instance_double(Document, original_document_id: original_document_id)
      end
      let(:documents) do
        [
          instance_double(Document, original_document_id: "123"),
          matching_document
        ]
      end

      before do
        allow(field).to receive(:original_document_id).and_return(original_document_id)
        allow(template).to receive(:documents).and_return(documents)
      end

      it "is the template document with the matching original_document_id" do
        expect(field.document).to be(matching_document)
      end
    end

    describe "document_id" do
      let(:document) do
        instance_double(Document, document_id: "123")
      end

      context "when there is a document" do
        before do
          allow(field).to receive(:document).and_return(document)
        end

        it "is the matching document document_id" do
          expect(field.document_id).to be(document.document_id)
        end
      end

      context "when there is not a document" do
        before do
          allow(field).to receive(:document).and_return(nil)
        end

        it "is nil" do
          expect(field.document_id).to be(nil)
        end
      end
    end

    describe "original_document_id" do
      it "returns the document_id from data" do
        document_id = "123"
        data[:document_id] = document_id
        expect(field.original_document_id).to eq(document_id)
      end
    end

    describe "page_number" do
      context "when a radio group" do
        let(:radios) do
          3.times.map do |index|
            Field.new(data.merge(page_number: index.to_s), template, true)
          end
        end

        before do
          allow(field).to receive(:is_radio_group?).and_return(true)
          allow(field).to receive(:radios).and_return(radios)
        end

        it "returns the page number of the first radio" do
          expect(field.page_number).to eq(radios.first.page_number)
        end
      end

      context "when not a radio group" do
        it "converts the page_number to an integer" do
          page_number = 5
          data[:page_number] = page_number.to_s
          expect(field.page_number).to eq(page_number)
        end
      end
    end

    describe "page_index" do
      it "subtracts one from the page number" do
        page_number = 5
        expect(field).to receive(:page_number).and_return(page_number)
        expect(field.page_index).to eq(page_number - 1)
      end
    end

    describe "is_radio_group?" do
      it "returns true if a radio group" do
        data[:tab_type] = Field::FieldTypes::RADIO_GROUP
        expect(field.is_radio_group?).to be(true)
      end

      it "returns false for other types" do
        data[:tab_type] = Field::FieldTypes::CHECKBOX
        expect(field.is_radio_group?).to be(false)
      end
    end

    describe "is_checkbox?" do
      it "returns true if a checkbox" do
        data[:tab_type] = Field::FieldTypes::CHECKBOX
        expect(field.is_checkbox?).to be(true)
      end

      it "returns false for other types" do
        data[:tab_type] = Field::FieldTypes::RADIO_GROUP
        expect(field.is_checkbox?).to be(false)
      end
    end

    describe "is_text?" do
      it "returns true if a text field" do
        data[:tab_type] = Field::FieldTypes::TEXT
        expect(field.is_text?).to be(true)
      end

      it "returns false for other types" do
        data[:tab_type] = Field::FieldTypes::RADIO_GROUP
        expect(field.is_text?).to be(false)
      end
    end

    describe "is_list?" do
      it "returns true if a list field" do
        data[:tab_type] = Field::FieldTypes::LIST
        expect(field.is_list?).to be(true)
      end

      it "returns false for other types" do
        data[:tab_type] = Field::FieldTypes::RADIO_GROUP
        expect(field.is_list?).to be(false)
      end
    end

    describe "is_pdf_field?" do
      it "is true if is_radio_group? is" do
        data[:tab_type] = Field::FieldTypes::RADIO_GROUP
        expect(field.is_pdf_field?).to be(true)
      end

      it "is true if is_checkbox? is" do
        data[:tab_type] = Field::FieldTypes::CHECKBOX
        expect(field.is_pdf_field?).to be(true)
      end

      it "is true if is_text? is" do
        data[:tab_type] = Field::FieldTypes::TEXT
        expect(field.is_pdf_field?).to be(true)
      end

      it "is true if is_list? is" do
        data[:tab_type] = Field::FieldTypes::LIST
        expect(field.is_pdf_field?).to be(true)
      end

      it "is false otherwise" do
        data[:tab_type] = Field::FieldTypes::SIGNATURE
        expect(field.is_pdf_field?).to be(false)
      end
    end

    describe "is_signature?" do
      it "is true for a signature" do
        data[:tab_type] = Field::FieldTypes::SIGNATURE
        expect(field.is_signature?).to be(true)
      end

      it "is true for an initial" do
        data[:tab_type] = Field::FieldTypes::INITIAL
        expect(field.is_signature?).to be(true)
      end

      it "is false otherwise" do
        data[:tab_type] = Field::FieldTypes::TEXT
        expect(field.is_signature?).to be(false)
      end
    end

    describe "radios" do
      let(:radios) do
        3.times.map do |index|
          data.merge(value: "value_#{index}")
        end
      end

      before do
        data[:radios] = radios
      end

      it "returns an empty array if not a radio group" do
        expect(field).to receive(:is_radio_group?).and_return(false)
        expect(field.radios).to eq([])
      end

      context "when a radio group" do
        before do
          allow(field).to receive(:is_radio_group?).and_return(true)
        end

        it "creates a radio for each radio in data" do
          radios.each_with_index do |raw_radio, index|
            expect(field.radios[index].data).to eq(raw_radio)
            expect(field.radios[index].is_radio?).to be(true)
          end
        end

        it "is memoized" do
          expect(field.radios).to be(field.radios)
        end
      end
    end

    describe "list_items" do
      let(:list_items) do
        3.times.map do |index|
          data.merge(value: "value_#{index}")
        end
      end

      before do
        data[:list_items] = list_items
      end

      it "returns an empty array if not a list" do
        expect(field).to receive(:is_list?).and_return(false)
        expect(field.list_items).to eq([])
      end

      context "when a list" do
        before do
          allow(field).to receive(:is_list?).and_return(true)
        end

        it "creates a list item for each list item in data" do
          list_items.each_with_index do |raw_item, index|
            expect(field.list_items[index].data).to eq(raw_item)
            expect(field.list_items[index].is_radio?).to be(true)
          end
        end

        it "is memoized" do
          expect(field.list_items).to be(field.list_items)
        end
      end
    end
  end
end
