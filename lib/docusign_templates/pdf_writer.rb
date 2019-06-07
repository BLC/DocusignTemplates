module DocusignTemplates
  class PdfWriter
    attr_reader :document, :recipients, :pdf

    BOX_COLOR = Origami::Graphics::Color::RGB.new(30, 30, 30)

    FONT_COLORS = {
      black: Origami::Graphics::Color::RGB.new(0, 0, 0),
      brightblue: Origami::Graphics::Color::RGB.new(30, 30, 30),
      brightred: Origami::Graphics::Color::RGB.new(219, 17, 17),
      darkgreen: Origami::Graphics::Color::RGB.new(18, 130, 21),
      darkred: Origami::Graphics::Color::RGB.new(114, 16, 16),
      gold: Origami::Graphics::Color::RGB.new(237, 187, 9),
      green: Origami::Graphics::Color::RGB.new(23, 170, 26),
      navyblue: Origami::Graphics::Color::RGB.new(41, 66, 112),
      purple: Origami::Graphics::Color::RGB.new(130, 11, 193),
      white: Origami::Graphics::Color::RGB.new(255, 255, 255)
    }

    def self.apply_fields!(document, recipients)
      PdfWriter.new(document, recipients).apply_fields!
    end

    def initialize(document, recipients)
      @document = document
      @recipients = recipients
      @pdf = Origami::PDF.read(document.path)
    end

    def apply_fields!
      render_pages
      output_pdf_data
    end

    private

    def render_pages
      pdf.pages.each_with_index do |page, page_index|
        render_page(page, page_index)
      end
    end

    def render_page(page, page_index)
      add_page_fonts(page)
      stream = Origami::ContentStream.new

      each_required_page_field(page_index) do |field|
        if field.is_checkbox?
          draw_checkbox(page, stream, field)
        elsif field.is_radio?
          draw_radio(page, stream, field)
        elsif field.is_text?
          draw_text(page, stream, field)
        elsif field.is_list?
          draw_list(page, stream, field)
        end
      end

      if page.Contents.is_a?(Array)
        page.Contents << stream
      else
        page.Contents = [page.Contents, stream]
      end
    end

    def each_required_page_field(page_index)
      recipients.each do |recipient|
        recipient.fields_for_document(document).each do |field|
          next if field.disabled?
          next if field.uploadable?

          if field.is_radio_group?
            field.radios.each do |radio|
              yield radio if radio.page_index == page_index
            end
          else
            yield field if field.page_index == page_index
          end
        end
      end
    end

    def add_page_fonts(page)
      page.add_font(Origami::Font::Type1::Standard::Courier.new.pre_build)
    end

    def to_page_coordinate(page, x, y, height)
      page_height = page.MediaBox.value[3] - page.MediaBox.value[1]
      new_x = x + page.MediaBox.value[0]
      new_y = page_height - y + page.MediaBox.value[1] - height
      { x: new_x, y: new_y }
    end

    def draw_checkbox(page, stream, field)
      return unless field.selected?

      checkbox_size = 13
      top_left = to_page_coordinate(page, field.x, field.y, checkbox_size)

      offset = 2
      line_width = 2
      half_line_width = line_width / 2

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

        stream.draw_line(start, finish, {
          stroke: true,
          line_width: line_width,
          line_cap: Origami::Graphics::LineCapStyle::ROUND_CAP,
          line_join: Origami::Graphics::LineJoinStyle::ROUND_JOIN,
          stroke_color: BOX_COLOR
        })
      end
    end

    def draw_radio(page, stream, radio)
      return unless radio.selected?

      radio_size = 13
      half_radio_size = radio_size / 2
      top_left = to_page_coordinate(page, radio.x, radio.y, radio_size)
      midpoint = [top_left[:x] + half_radio_size, top_left[:y] + half_radio_size]
      offset_midpoint = midpoint.map { |p| p + 0.1 }

      # line has to have some distance to show in DocuSign signing view
      stream.draw_line(midpoint, offset_midpoint, {
        stroke: true,
        line_width: half_radio_size * 1.5,
        line_cap: Origami::Graphics::LineCapStyle::ROUND_CAP,
        line_join: Origami::Graphics::LineJoinStyle::ROUND_JOIN,
        stroke_color: BOX_COLOR
      })
    end

    def draw_text(page, stream, field)
      return if field.value.nil?
      return if field.value.empty?

      # docusign renders text from top-left, pdf renders from bottom-left
      corrected_y = field.y - field.height + field.font_size
      options = to_page_coordinate(page, field.x, corrected_y, field.height).merge(
        size: field.font_size,
        color: get_font_color(field)
      )

      stream.write(field.value, options)
    end

    def draw_list(page, stream, field)
      selected_item = field.selected_item
      return unless selected_item

      options = to_page_coordinate(page, field.x, field.y, field.height).merge(
        size: field.font_size,
        color: get_font_color(field)
      )

      stream.write(selected_item.name, options)
    end

    def get_font_color(field)
      FONT_COLORS[field.font_color] || FONT_COLORS[:black]
    end

    # getting PDF data in-memory is currently a private method
    def output_pdf_data
      options = {
        delinearize: true,
        recompile: true,
        decrypt: false
      }

      pdf.delinearize! if pdf.linearized?
      pdf.send(:compile, options)
      pdf.send(:output, options)
    end
  end
end
