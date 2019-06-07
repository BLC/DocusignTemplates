module DocusignTemplates
  RSpec.describe PdfWriter do
    let(:path) { "path/to/the.pdf" }
    let(:document) { instance_double(Document, path: path) }
    let(:recipients) do
      [
        instance_double(Recipient),
        instance_double(Recipient)
      ]
    end

    let(:pdf) { instance_double(Origami::PDF) }
    let(:writer) { PdfWriter.new(document, recipients) }

    before do
      allow(Origami::PDF).to receive(:read).and_return(pdf)
    end

    describe ".apply_fields!" do
      it "calls apply_fields! on a new instance" do
        result = "pdf data 0101010101"
        instance = instance_double(PdfWriter, apply_fields!: result)
        expect(PdfWriter).to receive(:new).with(document, recipients).and_return(instance)
        expect(PdfWriter.apply_fields!(document, recipients)).to eq(result)
      end
    end

    describe "initialize" do
      it "sets documents and recipients" do
        expect(writer.document).to eq(document)
        expect(writer.recipients).to eq(recipients)
      end

      it "reads the pdf form the document path" do
        expect(Origami::PDF).to receive(:read).with(path)
        expect(writer.pdf).to be(pdf)
      end
    end

    describe "apply_fields!" do
      it "calls render_pages and then returns output_pdf_data" do
        result = "result"
        expect(writer).to receive(:render_pages)
        expect(writer).to receive(:output_pdf_data).and_return(result)
        expect(writer.apply_fields!).to eq(result)
      end
    end

    describe "render_pages" do
      let(:pages) do
        [
          instance_double(Origami::Page),
          instance_double(Origami::Page),
          instance_double(Origami::Page)
        ]
      end

      before do
        allow(pdf).to receive(:pages).and_return(pages)
      end

      it "renders a page for each page" do
        allow(writer).to receive(:render_page)

        pages.each_with_index do |page, page_index|
          expect(writer).to receive(:render_page).with(page, page_index)
        end

        writer.send(:render_pages)
      end
    end

    describe "render_page" do
      let(:page_index) { 1 }
      let(:contents) { instance_double(Origami::ContentStream) }

      let(:page) do
        result = instance_double(Origami::Page, Contents: contents)
        allow(result).to receive(:Contents=)
        result
      end

      before do
        allow(writer).to receive(:add_page_fonts)
        allow(writer).to receive(:each_required_page_field)
      end

      it "adds the fonts to the page" do
        expect(writer).to receive(:add_page_fonts).with(page)
        writer.send(:render_page, page, page_index)
      end

      context "page field handling" do
        let(:field) do
          instance_double(Field, {
            is_checkbox?: false,
            is_radio?: false,
            is_text?: false,
            is_list?: false
          })
        end

        before do
          allow(writer).to receive(:each_required_page_field).and_yield(field)
        end

        it "calls each_required_page_field with the page index" do
          expect(writer).to receive(:each_required_page_field).with(page_index)
          writer.send(:render_page, page, page_index)
        end

        context "when a checkbox" do
          before do
            allow(field).to receive(:is_checkbox?).and_return(true)
          end

          it "draws the checkbox" do
            expect(writer)
              .to receive(:draw_checkbox)
              .with(page, instance_of(Origami::ContentStream), field)

            writer.send(:render_page, page, page_index)
          end
        end

        context "when a radio" do
          before do
            allow(field).to receive(:is_radio?).and_return(true)
          end

          it "draws the checkbox" do
            expect(writer)
              .to receive(:draw_radio)
              .with(page, instance_of(Origami::ContentStream), field)

            writer.send(:render_page, page, page_index)
          end
        end

        describe "when text" do
          before do
            allow(field).to receive(:is_text?).and_return(true)
          end

          it "draws the checkbox" do
            expect(writer)
              .to receive(:draw_text)
              .with(page, instance_of(Origami::ContentStream), field)

            writer.send(:render_page, page, page_index)
          end
        end

        describe "when a list" do
          before do
            allow(field).to receive(:is_list?).and_return(true)
          end

          it "draws the checkbox" do
            expect(writer)
              .to receive(:draw_list)
              .with(page, instance_of(Origami::ContentStream), field)

            writer.send(:render_page, page, page_index)
          end
        end
      end

      it "appends a content stream to page Contents if already an array" do
        contents_array = [contents, contents]
        allow(page).to receive(:Contents).and_return(contents_array)

        writer.send(:render_page, page, page_index)
        expect(contents_array).to match_array(
          [contents, contents, an_instance_of(Origami::ContentStream)]
        )
      end

      it "sets the page Contents to an array of not yet an array" do
        expect(page).to receive(:Contents=)
          .with([contents, instance_of(Origami::ContentStream)])

        writer.send(:render_page, page, page_index)
      end
    end

    describe "each_required_page_field" do
      let(:page_index) { 1 }

      it "calls fields_for_document with the document for each recipient" do
        recipients.each do |recipient|
          expect(recipient).to receive(:fields_for_document).with(document).and_return([])
        end

        writer.send(:each_required_page_field, page_index)
      end

      it "does not yield disabled fields" do
        recipients.each do |recipient|
          expect(recipient).to receive(:fields_for_document).with(document).and_return([
            instance_double(Field, disabled?: true)
          ])
        end

        yielded_fields = []
        writer.send(:each_required_page_field, page_index) do |field|
          yielded_fields << field
        end

        expect(yielded_fields).to eq([])
      end

      it "does not yield uploadable fields" do
        recipients.each do |recipient|
          expect(recipient).to receive(:fields_for_document).with(document).and_return([
            instance_double(Field, disabled?: false, uploadable?: true)
          ])
        end

        yielded_fields = []
        writer.send(:each_required_page_field, page_index) do |field|
          yielded_fields << field
        end

        expect(yielded_fields).to eq([])
      end

      context "radio group fields" do
        let(:radios) do
          [
            instance_double(Field, page_index: 0),
            instance_double(Field, page_index: page_index)
          ]
        end

        it "yields each radio for the page index" do
          recipients.each do |recipient|
            expect(recipient).to receive(:fields_for_document).with(document).and_return([
              instance_double(Field, {
                disabled?: false,
                is_radio_group?: true,
                uploadable?: false,
                radios: radios
              })
            ])
          end

          yielded_fields = []
          writer.send(:each_required_page_field, page_index) do |field|
            yielded_fields << field
          end

          expect(yielded_fields.size).to eq(recipients.size)
          yielded_fields.each do |field|
            expect(field.page_index).to eq(page_index)
          end
        end
      end

      context "other field types" do
        it "yields each field for the page index" do
          recipients.each do |recipient|
            expect(recipient).to receive(:fields_for_document).with(document).and_return([
              instance_double(Field, {
                disabled?: false,
                is_radio_group?: false,
                page_index: 0,
                uploadable?: false
              }),
              instance_double(Field, {
                disabled?: false,
                is_radio_group?: false,
                page_index: page_index,
                uploadable?: false
              })
            ])
          end

          yielded_fields = []
          writer.send(:each_required_page_field, page_index) do |field|
            yielded_fields << field
          end

          expect(yielded_fields.size).to eq(recipients.size)
          yielded_fields.each do |field|
            expect(field.page_index).to eq(page_index)
          end
        end
      end
    end

    describe "add_page_fonts" do
      let(:page) { instance_double(Origami::Page) }

      it "adds the font to the page" do
        expect(page).to receive(:add_font).with(
          instance_of(Origami::Font::Type1::Standard::Courier)
        )

        writer.send(:add_page_fonts, page)
      end
    end

    describe "to_page_coordinate" do
      let(:coords) { [10,20,300,400] }
      let(:media_box) { double("MediaBox", value: coords) }
      let(:page) { instance_double(Origami::Page, MediaBox: media_box) }

      it "returns expected coordinates" do
        x = 42
        y = 69
        height = 12

        expect(writer.send(:to_page_coordinate, page, x, y, height)).to eq(
          x: x + coords[0],
          y: (coords[3] - coords[1]) - y + coords[1] - height
        )
      end
    end

    describe "draw_checkbox" do
      let(:x) { 50 }
      let(:y) { 60 }

      let(:page) { instance_double(Origami::Page) }
      let(:stream) { instance_double(Origami::ContentStream) }
      let(:field) { instance_double(Field, x: x, y: y) }

      let(:coords) do
        { x: x + 10, y: y + 10 }
      end

      before do
        allow(writer).to receive(:to_page_coordinate).and_return(coords)
        allow(stream).to receive(:draw_line)
      end

      it "does not draw anything if the field is not selected" do
        expect(field).to receive(:selected?).and_return(false)
        expect(stream).not_to receive(:draw_line)
        writer.send(:draw_checkbox, page, stream, field)
      end

      context "when the field is selected" do
        before do
          allow(field).to receive(:selected?).and_return(true)
        end

        it "draws two lines to form an x" do
          checkbox_size = 13
          top_left = coords

          offset = 2
          line_width = 2
          half_line_width = line_width / 2

          expect(writer).to receive(:to_page_coordinate).with(page, x, y, checkbox_size)

          corners = [
            [offset + half_line_width, offset + half_line_width ],
            [checkbox_size - offset - half_line_width, offset + half_line_width],
            [offset + half_line_width, checkbox_size - offset - half_line_width],
            [checkbox_size - offset - half_line_width, checkbox_size - offset - half_line_width]
          ].map do |coords|
            x, y = coords
            [top_left[:x] + x, top_left[:y] + y]
          end

          [
            [corners[0], corners[3]],
            [corners[1], corners[2]]
          ].each do |cross_points|
            start, finish = cross_points

            expect(stream).to receive(:draw_line).with(
              start, finish, {
                stroke: true,
                line_width: line_width,
                line_cap: Origami::Graphics::LineCapStyle::ROUND_CAP,
                line_join: Origami::Graphics::LineJoinStyle::ROUND_JOIN,
                stroke_color: PdfWriter::BOX_COLOR
              }
            )
          end

          writer.send(:draw_checkbox, page, stream, field)
        end
      end
    end

    describe "draw_radio" do
      let(:x) { 50 }
      let(:y) { 60 }

      let(:page) { instance_double(Origami::Page) }
      let(:stream) { instance_double(Origami::ContentStream) }
      let(:field) { instance_double(Field, x: x, y: y) }

      let(:coords) do
        { x: x + 10, y: y + 10 }
      end

      before do
        allow(writer).to receive(:to_page_coordinate).and_return(coords)
        allow(stream).to receive(:draw_line)
      end

      it "does not draw anything if the field is not selected" do
        expect(field).to receive(:selected?).and_return(false)
        expect(stream).not_to receive(:draw_line)
        writer.send(:draw_radio, page, stream, field)
      end

      context "when the field is selected" do
        before do
          allow(field).to receive(:selected?).and_return(true)
        end

        it "draws the radio" do
          radio_size = 13
          half_radio_size = radio_size / 2
          top_left = coords
          midpoint = [top_left[:x] + half_radio_size, top_left[:y] + half_radio_size]
          offset_midpoint = midpoint.map { |p| p + 0.1 }

          expect(writer).to receive(:to_page_coordinate).with(page, x, y, radio_size)
          expect(stream).to receive(:draw_line).with(midpoint, offset_midpoint, {
            stroke: true,
            line_width: half_radio_size * 1.5,
            line_cap: Origami::Graphics::LineCapStyle::ROUND_CAP,
            line_join: Origami::Graphics::LineJoinStyle::ROUND_JOIN,
            stroke_color: PdfWriter::BOX_COLOR
          })

          writer.send(:draw_radio, page, stream, field)
        end
      end
    end

    describe "draw_text" do
      let(:x) { 50 }
      let(:y) { 60 }
      let(:height) { 20 }
      let(:width) { 100 }
      let(:font_size) { 12 }

      let(:page) { instance_double(Origami::Page) }
      let(:stream) { instance_double(Origami::ContentStream) }
      let(:field) { instance_double(Field, x: x, y: y, width: width, height: height, font_size: 12) }

      let(:color) { "some color" }

      let(:coords) do
        { x: x + 10, y: y + 10 }
      end

      before do
        allow(writer).to receive(:to_page_coordinate).and_return(coords)
        allow(writer).to receive(:get_font_color).and_return(color)
        allow(stream).to receive(:write)
      end

      it "draws nothing if the value is nil" do
        expect(field).to receive(:value).and_return(nil)
        expect(stream).not_to receive(:write)
        writer.send(:draw_text, page, stream, field)
      end

      it "draws nothing if the value is empty" do
        allow(field).to receive(:value).and_return("")
        expect(stream).not_to receive(:write)
        writer.send(:draw_text, page, stream, field)
      end

      context "when there is a value" do
        let(:value) { "some value" }

        before do
          allow(field).to receive(:value).and_return(value)
        end

        it "draws the text" do
          expect(writer).to receive(:to_page_coordinate).with(
            page, x, y - height + font_size, height
          )

          expect(writer).to receive(:get_font_color).with(field)

          expect(stream).to receive(:write).with(
            value, coords.merge(size: font_size, color: color)
          )

          writer.send(:draw_text, page, stream, field)
        end
      end
    end

    describe "draw_list" do
      let(:x) { 50 }
      let(:y) { 60 }
      let(:height) { 20 }
      let(:width) { 100 }
      let(:font_size) { 12 }

      let(:page) { instance_double(Origami::Page) }
      let(:stream) { instance_double(Origami::ContentStream) }
      let(:field) { instance_double(Field, x: x, y: y, width: width, height: height, font_size: 12) }

      let(:color) { "some color" }

      let(:coords) do
        { x: x + 10, y: y + 10 }
      end

      before do
        allow(writer).to receive(:to_page_coordinate).and_return(coords)
        allow(writer).to receive(:get_font_color).and_return(color)
        allow(stream).to receive(:write)
      end

      it "renders nothing if there is no selected_item" do
        expect(field).to receive(:selected_item).and_return(nil)
        expect(stream).not_to receive(:write)
        writer.send(:draw_list, page, stream, field)
      end

      context "when there is a selected_item" do
        let(:name) { "item name" }
        let(:selected_item) { instance_double(Field, name: name) }

        before do
          allow(field).to receive(:selected_item).and_return(selected_item)
        end

        it "draws the selected item" do
          expect(writer).to receive(:to_page_coordinate).with(
            page, x, y, height
          )

          expect(writer).to receive(:get_font_color).with(field)

          expect(stream).to receive(:write).with(
            name, coords.merge(size: font_size, color: color)
          )

          writer.send(:draw_list, page, stream, field)
        end
      end
    end

    describe "get_font_color" do
      it "gets the font_color from the mapping" do
        field = instance_double(Field, font_color: :brightred)
        expect(writer.send(:get_font_color, field)).to eq(
          PdfWriter::FONT_COLORS[:brightred]
        )
      end

      it "returns black if the color if not mapped" do
        field = instance_double(Field, font_color: :fake)
        expect(writer.send(:get_font_color, field)).to eq(
          PdfWriter::FONT_COLORS[:black]
        )
      end
    end

    describe "output_pdf_data" do
      it "outptus pdf data correctly" do
        options = {
          delinearize: true,
          recompile: true,
          decrypt: false
        }

        result = "pdf data 0101010101"
        expect(pdf).to receive(:linearized?).and_return(false)
        expect(pdf).to receive(:compile).with(options)
        expect(pdf).to receive(:output).with(options).and_return(result)
        expect(writer.send(:output_pdf_data)).to eq(result)
      end

      it "delinearizes the pdf if linearized" do
        options = {
          delinearize: true,
          recompile: true,
          decrypt: false
        }

        result = "pdf data 0101010101"
        expect(pdf).to receive(:linearized?).and_return(true)
        expect(pdf).to receive(:delinearize!)
        expect(pdf).to receive(:compile).with(options)
        expect(pdf).to receive(:output).with(options).and_return(result)
        expect(writer.send(:output_pdf_data)).to eq(result)
      end
    end
  end
end
