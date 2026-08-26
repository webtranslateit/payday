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
        details: details
      }
    end

    def stamp
      return t('status.refunded', 'REFUNDED') if @invoice.refunded?
      return t('status.paid', 'PAID') if @invoice.paid?

      t('status.overdue', 'OVERDUE') if @invoice.overdue?
    end

    def details
      rows = []
      rows << [number_label, @invoice.invoice_number.to_s] if @invoice.invoice_number
      rows << [t('invoice.due_date', 'Due Date:'), date(@invoice.due_at)] if @invoice.due_at
      rows << [t('invoice.paid_date', 'Paid Date:'), date(@invoice.paid_at)] if @invoice.paid_at
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
