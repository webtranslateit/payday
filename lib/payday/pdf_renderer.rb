# frozen_string_literal: true

module Payday

  # The PDF renderer. We use this internally in Payday to render pdfs, but really you should just need to call
  # {{Payday::Invoiceable#render_pdf}} to render pdfs yourself.
  class PdfRenderer # rubocop:todo Metrics/ClassLength

    # Renders the given invoice as a pdf on disk
    def self.render_to_file(invoice, path)
      pdf(invoice).render_file(path)
    end

    # Renders the given invoice as a pdf, returning a string
    def self.render(invoice)
      pdf(invoice).render
    end

    def self.pdf(invoice) # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      pdf = Prawn::Document.new(page_size: invoice_or_default(invoice, :page_size))

      font_dir = File.join(File.dirname(__dir__), '..', 'fonts')
      pdf.font_families.update(
        'NotoSans' => {normal: File.join(font_dir, 'NotoSans-Regular.ttf'),
                       bold: File.join(font_dir, 'NotoSans-Bold.ttf')}
      )

      # set up some default styling
      pdf.font_size(10)
      pdf.font 'NotoSans'

      stamp(invoice, pdf)
      company_banner(invoice, pdf)
      bill_to_ship_to(invoice, pdf)
      invoice_details(invoice, pdf)
      line_items_table(invoice, pdf)
      totals_lines(invoice, pdf)
      notes(invoice, pdf)
      render_qr_code(invoice, pdf) unless defined?(invoice.notes) && invoice.notes

      page_numbers(pdf)

      pdf
    end

    def self.stamp(invoice, pdf) # rubocop:todo Metrics/MethodLength
      stamp = nil
      if invoice.refunded?
        stamp = I18n.t 'payday.status.refunded', default: 'REFUNDED'
      elsif invoice.paid?
        stamp = I18n.t 'payday.status.paid', default: 'PAID'
      elsif invoice.overdue?
        stamp = I18n.t 'payday.status.overdue', default: 'OVERDUE'
      end

      if stamp
        pdf.bounding_box([150, pdf.cursor - 50], width: pdf.bounds.width - 300) do
          pdf.font('NotoSans') do
            pdf.fill_color 'cc0000'
            pdf.text stamp, align: :center, size: 25, rotate: 15, style: :bold
          end
        end
      end

      pdf.fill_color '000000'
    end

    # rubocop:todo Metrics/MethodLength
    def self.company_banner(invoice, pdf) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      # render the logo
      image = invoice_or_default(invoice, :invoice_logo)
      height = nil
      width = nil

      # Handle images defined with a hash of options
      if image.is_a?(Hash)
        data = image
        image = data[:filename]
        width, height = data[:size].split('x').map(&:to_f)
      end

      if File.extname(image) == '.svg'
        logo_info = pdf.svg(File.read(image), at: pdf.bounds.top_left, width: width, height: height)
        logo_height = logo_info[:height]
      else
        logo_info = pdf.image(image, at: pdf.bounds.top_left, width: width, height: height)
        logo_height = logo_info.scaled_height
      end

      # render the company details
      table_data = []
      table_data << [bold_cell(pdf, invoice_or_default(invoice, :company_name).strip, size: 12)]

      invoice_or_default(invoice, :company_details).lines.each { |line| table_data << [line] }

      table = pdf.make_table(table_data, cell_style: {borders: [], padding: 0})
      pdf.bounding_box([pdf.bounds.width - table.width, pdf.bounds.top], width: table.width,
                                                                         height: table.height + 5) do
        table.draw
      end

      pdf.move_cursor_to(pdf.bounds.top - logo_height - 20)
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:todo Metrics/MethodLength
    def self.bill_to_ship_to(invoice, pdf) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      bill_to_cell_style = {borders: [], padding: [2, 0]}
      bill_to_ship_to_bottom = 0

      # render bill to
      pdf.float do
        pdf.table([[bold_cell(pdf, I18n.t('payday.invoice.bill_to', default: 'Bill To'))],
                   [invoice.bill_to]], column_widths: [200], cell_style: bill_to_cell_style)
        bill_to_ship_to_bottom = pdf.cursor
      end

      # render ship to
      if defined?(invoice.ship_to) && !invoice.ship_to.nil?
        table = pdf.make_table([[bold_cell(pdf, I18n.t('payday.invoice.ship_to', default: 'Ship To'))],
                                [invoice.ship_to]], column_widths: [200], cell_style: bill_to_cell_style)

        pdf.bounding_box([pdf.bounds.width - table.width, pdf.cursor], width: table.width, height: table.height + 2) do
          table.draw
        end
      end

      # make sure we start at the lower of the bill_to or ship_to details
      bill_to_ship_to_bottom = pdf.cursor if pdf.cursor < bill_to_ship_to_bottom
      pdf.move_cursor_to(bill_to_ship_to_bottom - 20)
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/AbcSize
    def self.invoice_details(invoice, pdf) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      # invoice details
      table_data = []

      # invoice number
      if defined?(invoice.invoice_number) && invoice.invoice_number
        table_data << if invoice.paid?
          [bold_cell(pdf, I18n.t('payday.invoice.receipt_no', default: 'Receipt #:')),
           bold_cell(pdf, invoice.invoice_number.to_s, align: :right)]
        else
          [bold_cell(pdf, I18n.t('payday.invoice.invoice_no', default: 'Invoice #:')),
           bold_cell(pdf, invoice.invoice_number.to_s, align: :right)]
        end
      end

      # Due on
      if defined?(invoice.due_at) && invoice.due_at
        due_date = if invoice.due_at.is_a?(Date) || invoice.due_at.is_a?(Time)
          invoice.due_at.strftime(Payday::Config.default.date_format)
        else
          invoice.due_at.to_s
        end

        table_data << [bold_cell(pdf, I18n.t('payday.invoice.due_date', default: 'Due Date:')),
                       bold_cell(pdf, due_date, align: :right)]
      end

      # Paid on
      if defined?(invoice.paid_at) && invoice.paid_at
        paid_date = if invoice.paid_at.is_a?(Date) || invoice.due_at.is_a?(Time)
          invoice.paid_at.strftime(Payday::Config.default.date_format)
        else
          invoice.paid_at.to_s
        end

        table_data << [bold_cell(pdf, I18n.t('payday.invoice.paid_date', default: 'Paid Date:')),
                       bold_cell(pdf, paid_date, align: :right)]
      end

      # loop through invoice_details and include them
      invoice.each_detail do |key, value|
        table_data << [bold_cell(pdf, key),
                       bold_cell(pdf, value, align: :right)]
      end

      return unless table_data.length.positive?

      pdf.table(table_data, cell_style: {borders: [], padding: [1, 10, 1, 1]})
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    # rubocop:todo Metrics/MethodLength
    def self.line_items_table(invoice, pdf) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      table_data = []
      table_data << [bold_cell(pdf, I18n.t('payday.line_item.description', default: 'Description'), borders: []),
                     bold_cell(pdf, I18n.t('payday.line_item.unit_price', default: 'Unit Price'), align: :center,
                                                                                                  borders: []),
                     bold_cell(pdf, I18n.t('payday.line_item.quantity', default: 'Quantity'), align: :center,
                                                                                              borders: []),
                     bold_cell(pdf, I18n.t('payday.line_item.amount', default: 'Amount'), align: :center, borders: [])]
      invoice.line_items.each do |line|
        table_data << if line.predefined_amount
          [line.description, '', '', number_to_currency(line.predefined_amount, invoice)]
        else
          [line.description,
           line.display_price || number_to_currency(line.price, invoice),
           line.display_quantity || BigDecimal(line.quantity.to_s).to_s('F'),
           number_to_currency(line.amount, invoice)]
        end
      end

      pdf.move_cursor_to(pdf.cursor - 20)
      pdf.table(table_data, width: pdf.bounds.width, header: true,
                            cell_style: {border_width: 0.5, border_left_color: 'FFFFFF', border_right_color: 'FFFFFF',
                                         border_top_color: 'F6F9FC', border_bottom_color: 'BCC6D0', padding: [5, 10],
                                         inline_format: true},
                            row_colors: %w[F6F9FC ffffff]) do
        # left align the number columns
        columns(1..3).rows(1..(row_length - 1)).style(align: :right)

        # set the column widths correctly
        natural = natural_column_widths
        natural[0] = width - natural[1] - natural[2] - natural[3]
      end
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:todo Metrics/MethodLength
    def self.totals_lines(invoice, pdf) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      table_data = []
      table_data << [
        bold_cell(pdf, I18n.t('payday.invoice.subtotal', default: 'Subtotal:')),
        cell(pdf, number_to_currency(invoice.subtotal, invoice), align: :right)
      ]

      tax_description = if invoice.tax_description.nil?
        I18n.t('payday.invoice.tax', default: 'Tax:')
      else
        invoice.tax_description
      end

      table_data << [
        bold_cell(pdf, tax_description),
        cell(pdf, number_to_currency(invoice.tax, invoice), align: :right)
      ]

      if invoice.shipping_rate.positive?
        shipping_description = if invoice.shipping_description.nil?
          I18n.t('payday.invoice.shipping', default: 'Shipping:')
        else
          invoice.shipping_description
        end

        table_data << [
          bold_cell(pdf, shipping_description),
          cell(pdf, number_to_currency(invoice.shipping, invoice),
               align: :right)
        ]
      end
      table_data << [
        bold_cell(pdf, I18n.t('payday.invoice.total', default: 'Total:'),
                  size: 12),
        cell(pdf, number_to_currency(invoice.total, invoice),
             size: 12, align: :right)
      ]
      table = pdf.make_table(table_data, cell_style: {borders: []})
      pdf.bounding_box([pdf.bounds.width - table.width, pdf.cursor],
                       width: table.width, height: table.height + 2) do
        table.draw
      end
    end
    # rubocop:enable Metrics/MethodLength

    def self.notes(invoice, pdf) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      return unless defined?(invoice.notes) && invoice.notes

      pdf.move_cursor_to(pdf.cursor - 30)
      pdf.font('NotoSans') do
        pdf.text(I18n.t('payday.invoice.notes', default: 'Notes'), style: :bold)
      end
      pdf.line_width = 0.5
      pdf.stroke_color = 'cccccc'
      pdf.stroke_line([0, pdf.cursor - 3, pdf.bounds.width, pdf.cursor - 3])
      pdf.move_cursor_to(pdf.cursor - 10)
      pdf.text(invoice.notes.to_s, inline_format: true)

      render_qr_code(invoice, pdf)
    end

    def self.render_qr_code(invoice, pdf)
      return unless defined?(invoice.qr_code) && invoice.qr_code.to_s.strip.present?

      require 'rqrcode'

      pdf.move_cursor_to(pdf.cursor - 10)
      qr = RQRCode::QRCode.new(invoice.qr_code.to_s)
      png = qr.as_png(size: 200)

      pdf.image(StringIO.new(png.to_s), width: 100, position: :left)
    end

    def self.page_numbers(pdf)
      return unless pdf.page_count > 1

      pdf.number_pages('<page> / <total>', at: [pdf.bounds.right - 25, -10])
    end

    def self.invoice_or_default(invoice, property)
      if invoice.respond_to?(property) && invoice.send(property)
        invoice.send(property)
      else
        Payday::Config.default.send(property)
      end
    end

    def self.cell(pdf, text, options = {})
      Prawn::Table::Cell::Text.make(pdf, text, options)
    end

    def self.bold_cell(pdf, text, options = {})
      cell(pdf, "<b>#{text}</b>", options.merge(inline_format: true))
    end

    # Converts this number to a formatted currency string
    def self.number_to_currency(number, invoice)
      Money.locale_backend = :currency
      Money.rounding_mode = BigDecimal::ROUND_HALF_UP
      currency = Money::Currency.wrap(invoice_or_default(invoice, :currency))
      number *= currency.subunit_to_unit
      number = number.round unless Money.default_infinite_precision
      Money.new(number, currency).format
    end

    def self.max_cell_width(cell_proxy)
      max = 0
      cell_proxy.each do |cell|
        max = cell.natural_content_width if cell.natural_content_width > max
      end

      max
    end

  end

end
