module DocusignTemplates
  class Field
    module FieldTypes
      TEXT = "text"
      CHECKBOX = "checkbox"
      RADIO_GROUP = "radiogroup"
      SSN = "ssn"
      LIST = "list"
      SIGNATURE = "signhere"
      INITIAL = "initialhere"
    end

    attr_reader :data
    attr_accessor :disabled

    def initialize(data, is_radio = false)
      @data = data.deep_dup
      @disabled = false
      @is_radio = is_radio
      @uploadable = false

      # tab positions in downloaded templates are systematically off
      @original_positions = correct_positions!
    end

    def as_composite_template_entry
      if is_radio_group?
        data.merge(radios: radios.map(&:as_composite_template_entry))
      elsif is_list?
        data.merge(@original_positions).merge(
          list_items: list_items.map(&:as_composite_template_entry)
        )
      elsif is_pdf_field? || is_radio?
        # PDF fields need positions un-corrected when uploaded
        data.merge(@original_positions)
      else
        data
      end
    end

    def merge!(other_data)
      data.merge!(other_data)
    end

    def is_radio?
      @is_radio
    end

    def selected?
      data[:selected] == "true" ? true : false
    end

    def value
      if is_checkbox?
        selected?
      elsif is_radio_group? || is_list?
        item = selected_item
        item ? item.value : nil
      else
        data[:value]
      end
    end

    def value=(new_value)
      if is_checkbox? # boolean
        data[:selected] = new_value.to_s
      elsif is_radio_group? # value to select
        radios.each do |radio|
          radio.data[:selected] = (new_value.to_s == radio.value).to_s
        end
      elsif is_list? # value to select
        list_items.each do |list_item|
          list_item.data[:selected] = (new_value.to_s == list_item.value).to_s
        end
      else # string value
        data[:value] = new_value.to_s
      end
    end

    def disabled?
      disabled
    end

    def uploadable?
      if is_pdf_field?
        @uploadable
      else
        true
      end
    end

    def uploadable=(value)
      boolean_value = !!value
      @uploadable = boolean_value

      if is_radio_group?
        radios.each do |radio|
          radio.data[:locked] = boolean_value.to_s
        end
      else
        data[:locked] = boolean_value.to_s
      end
    end

    def label
      data[:group_name] || data[:tab_label]
    end

    def name
      data[:name] || data[:text]
    end

    def selected_item
      if is_radio_group?
        radios.find do |radio|
          radio.selected?
        end
      elsif is_list?
        list_items.find do |list_item|
          list_item.selected?
        end
      else
        nil
      end
    end

    def x
      data[:x_position].to_i
    end

    def y
      data[:y_position].to_i
    end

    def width
      if data[:width] # some fields only list height
        data[:width].to_i
      else
        height
      end
    end

    def height
      height = data[:height].to_i

      if height == 0 || height.nil? # height is font_size if not otherwise specified
        font_size
      else
        height
      end
    end

    def font_color
      if data[:font_color]
        data[:font_color].to_sym
      else
        :black
      end
    end

    def font_size
      if data[:font_size]
        data[:font_size].gsub('size', '').to_i
      else
        10
      end
    end

    def recipient_id
      data[:recipient_id]
    end

    def document_id
      data[:document_id]
    end

    def page_number
      if is_radio_group?
        radios.first.page_number
      else
        data[:page_number].to_i
      end
    end

    def page_index
      page_number - 1
    end

    def is_radio_group?
      data[:tab_type] == FieldTypes::RADIO_GROUP
    end

    def is_checkbox?
      data[:tab_type] == FieldTypes::CHECKBOX
    end

    def is_text?
      data[:tab_type] == FieldTypes::TEXT || data[:tab_type] == FieldTypes::SSN
    end

    def is_list?
      data[:tab_type] == FieldTypes::LIST
    end

    def is_pdf_field?
      is_radio_group? || is_checkbox? || is_text? || is_list?
    end

    def is_signature?
      data[:tab_type] == FieldTypes::SIGNATURE || data[:tab_type] == FieldTypes::INITIAL
    end

    def radios
      return [] unless is_radio_group?

      @radios ||= data[:radios].map do |radio|
        Field.new(radio, true)
      end
    end

    def list_items
      return [] unless is_list?

      @list_items ||= data[:list_items].map do |list_item|
        Field.new(list_item, true)
      end
    end

    private

    def correct_positions!
      original_positions = {}

      if data[:x_position]
        old_x = x
        data[:x_position] = (x + x_correction).to_s
        original_positions[:x_position] = old_x.to_s
      end

      if data[:y_position]
        old_y = y
        data[:y_position] = (y + y_correction).to_s
        original_positions[:y_position] = old_y.to_s
      end

      original_positions
    end

    def x_correction
      if is_pdf_field? || is_radio?
        3
      else
        0
      end
    end

    def y_correction
      if is_pdf_field? || is_radio?
        1
      elsif is_signature?
        -21
      else
        0
      end
    end
  end
end
