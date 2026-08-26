# frozen_string_literal: true

module Payday

  # Renders an invoice to PDF by feeding a presented Hash to the Typst template.
  #
  # Invoice data crosses into the template only as sys_inputs JSON, where Typst treats every
  # string as literal text. Never interpolate invoice data into the template source.
  class PdfRenderer

    TEMPLATE = File.expand_path('templates/invoice.typ', __dir__)
    FONT_DIR = File.expand_path('../../fonts', __dir__)
    FONTS = %w[NotoSans-Regular.ttf NotoSans-Bold.ttf].freeze

    # Renders the given invoice as a pdf on disk
    def self.render_to_file(invoice, path)
      File.binwrite(path, render(invoice))
    end

    # Renders the given invoice as a pdf, returning a string
    def self.render(invoice)
      new(invoice).render
    end

    # Converts this number to a formatted currency string
    def self.number_to_currency(number, invoice)
      Money.locale_backend = :currency
      Money.rounding_mode = BigDecimal::ROUND_HALF_UP
      currency = Money::Currency.wrap(currency_for(invoice))
      number *= currency.subunit_to_unit
      number = number.round unless Money.default_infinite_precision
      Money.new(number, currency).format
    end

    def self.currency_for(invoice)
      return invoice.currency if invoice.respond_to?(:currency) && invoice.currency

      Payday::Config.default.currency
    end
    private_class_method :currency_for

    def initialize(invoice)
      @invoice = invoice
      @dependencies = {}
    end

    def render
      data = InvoicePresenter.new(@invoice).to_h
      register_qr_code(data[:qr_code])
      data[:logo] = logo

      Typst(body: File.read(TEMPLATE), dependencies: @dependencies, fonts: fonts,
            sys_inputs: {'invoice' => data.to_json})
        .compile(:pdf).bytes.flatten.pack('C*')
    end

    private

    def fonts
      FONTS.to_h { |name| [name, File.binread(File.join(FONT_DIR, name))] }
    end

    # Config#invoice_logo is either a path or a {filename:, size: "WxH"} Hash.
    def logo
      setting = invoice_logo
      return nil if setting.nil?

      path, width, height = logo_parts(setting)
      name = "logo#{File.extname(path.to_s)}"
      @dependencies[name] = File.binread(path.to_s)
      {name: name, width: width, height: height}
    end

    def invoice_logo
      return @invoice.invoice_logo if @invoice.respond_to?(:invoice_logo) && @invoice.invoice_logo

      Payday::Config.default.invoice_logo
    end

    def logo_parts(setting)
      return [setting, nil, nil] unless setting.is_a?(Hash)

      width, height = setting[:size].to_s.split('x').map(&:to_f)
      [setting[:filename], width, height]
    end

    def register_qr_code(data)
      return if data.nil?

      @dependencies['qr.svg'] = QrCode.new(data).to_svg
    end

  end

end
