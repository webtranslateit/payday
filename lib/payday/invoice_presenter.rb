# frozen_string_literal: true

module Payday

  # Turns an Invoiceable into the plain Hash the Typst template consumes.
  #
  # Every currency, date and translation decision happens here, so the template stays a pure
  # layout concern and receives nothing but literal strings.
  class InvoicePresenter

    def initialize(invoice)
      @invoice = invoice
    end

    def to_h
      {
        page_size: setting(:page_size),
        company_name: setting(:company_name).strip,
        company_details: setting(:company_details),
        stamp: stamp,
        bill_to: @invoice.bill_to,
        ship_to: ship_to,
        labels: labels,
        details: details,
        line_items: line_items,
        totals: totals,
        notes: Markup.to_runs(@invoice.notes),
        qr_code: qr_code
      }
    end

    def line_items
      @invoice.line_items.map { |line| line_item(line) }
    end

    def totals
      [[t('invoice.subtotal', 'Subtotal:'), money(@invoice.subtotal), false],
       [tax_label, money(@invoice.tax), false],
       *shipping_row,
       *retention_row,
       [t('invoice.total', 'Total:'), money(@invoice.total), true]]
    end

    def stamp
      return t('status.refunded', 'REFUNDED') if @invoice.refunded?
      return t('status.paid', 'PAID') if @invoice.paid?

      t('status.overdue', 'OVERDUE') if @invoice.overdue?
    end

    def details
      rows = [*number_row, *due_row, *paid_row]
      @invoice.each_detail { |key, value| rows << [key.to_s, value.to_s] }
      rows
    end

    def labels
      {
        bill_to: t('invoice.bill_to', 'Bill To'),
        ship_to: t('invoice.ship_to', 'Ship To'),
        notes: t('invoice.notes', 'Notes'),
        description: t('line_item.description', 'Description'),
        unit_price: t('line_item.unit_price', 'Unit Price'),
        quantity: t('line_item.quantity', 'Quantity'),
        amount: t('line_item.amount', 'Amount')
      }
    end

    private

    def shipping_row
      [[shipping_label, money(@invoice.shipping), false]] if @invoice.shipping_rate.positive?
    end

    def retention_row
      [[retention_label, money(-@invoice.retention), false]] if @invoice.retention_rate.positive?
    end

    def number_row
      [[number_label, @invoice.invoice_number.to_s]] if @invoice.invoice_number
    end

    def due_row
      [[t('invoice.due_date', 'Due Date:'), date(@invoice.due_at)]] if @invoice.due_at
    end

    def paid_row
      [[t('invoice.paid_date', 'Paid Date:'), date(@invoice.paid_at)]] if @invoice.paid_at
    end

    def qr_code
      return nil unless @invoice.respond_to?(:qr_code) && @invoice.qr_code.to_s.strip.present?

      @invoice.qr_code.to_s
    end

    def line_item(line)
      return predefined_line_item(line) if line.predefined_amount

      {description: Markup.to_runs(line.description),
       price: line.display_price || money(line.price),
       quantity: line.display_quantity || BigDecimal(line.quantity.to_s).to_s('F'),
       amount: money(line.amount)}
    end

    def predefined_line_item(line)
      {description: Markup.to_runs(line.description), price: '', quantity: '',
       amount: money(line.predefined_amount)}
    end

    def tax_label
      @invoice.tax_description || t('invoice.tax', 'Tax:')
    end

    def shipping_label
      @invoice.shipping_description || t('invoice.shipping', 'Shipping:')
    end

    def retention_label
      @invoice.retention_description || t('invoice.retention', 'Retention:')
    end

    def money(number)
      PdfRenderer.number_to_currency(number, @invoice)
    end

    def ship_to
      @invoice.ship_to if @invoice.respond_to?(:ship_to)
    end

    def number_label
      return t('invoice.receipt_no', 'Receipt #:') if @invoice.paid?

      t('invoice.invoice_no', 'Invoice #:')
    end

    def date(value)
      return value.to_s unless value.is_a?(Date) || value.is_a?(Time)

      value.strftime(Payday::Config.default.date_format)
    end

    def t(key, default)
      I18n.t("payday.#{key}", default: default)
    end

    def setting(property)
      return @invoice.send(property) if @invoice.respond_to?(property) && @invoice.send(property)

      Payday::Config.default.send(property)
    end

  end

end
