# frozen_string_literal: true

require 'spec_helper'

module Payday # rubocop:todo Metrics/ModuleLength

  describe Invoice do
    # rubocop:todo RSpec/MultipleExpectations
    it 'is able to be initialized with a hash of options' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      i = described_class.new(invoice_number: 20, bill_to: 'Here', ship_to: 'There',
                              notes: 'These are some notes.',
                              line_items:
                        [LineItem.new(price: 10, quantity: 3, description: 'Shirts')],
                              shipping_rate: 15.00, shipping_description: 'USPS Priority Mail:',
                              tax_rate: 0.125, tax_description: 'Local Sales Tax, 12.5%',
                              invoice_date: Date.civil(1993, 4, 12))

      expect(i.invoice_number).to eq(20)
      expect(i.bill_to).to eq('Here')
      expect(i.ship_to).to eq('There')
      expect(i.notes).to eq('These are some notes.')
      expect(i.line_items[0].description).to eq('Shirts')
      expect(i.shipping_rate).to eq(BigDecimal('15.00'))
      expect(i.shipping_description).to eq('USPS Priority Mail:')
      expect(i.tax_rate).to eq(BigDecimal('0.125'))
      expect(i.tax_description).to eq('Local Sales Tax, 12.5%')
      expect(i.invoice_date).to eq(Date.civil(1993, 4, 12))
    end

    it 'totals all of the line items into a subtotal correctly' do # rubocop:todo RSpec/ExampleLength
      i = described_class.new

      # $100 in Pants
      i.line_items << LineItem.new(price: 20, quantity: 5, description: 'Pants')

      # $30 in Shirts
      i.line_items <<
        LineItem.new(price: 10, quantity: 3, description: 'Shirts')

      # $1000 in Hats
      i.line_items << LineItem.new(price: 5, quantity: 200, description: 'Hats')

      expect(i.subtotal).to eq(BigDecimal('1130'))
    end

    it 'calculates the correct tax rounded to two decimal places' do
      i = described_class.new(tax_rate: 10.0)
      i.line_items << LineItem.new(price: 20, quantity: 5, description: 'Pants')

      expect(i.tax).to eq(BigDecimal('10'))
    end

    it 'does not apply taxes to invoices with subtotal <= 0' do
      i = described_class.new(tax_rate: 10.0)
      i.line_items << LineItem.new(price: -1, quantity: 100,
                                   description: 'Negative Priced Pants')

      expect(i.tax).to eq(BigDecimal('-10'))
    end

    it 'calculates the total for an invoice correctly' do # rubocop:todo RSpec/ExampleLength
      i = described_class.new(tax_rate: 10.0)

      # $100 in Pants
      i.line_items << LineItem.new(price: 20, quantity: 5, description: 'Pants')

      # $30 in Shirts
      i.line_items <<
        LineItem.new(price: 10, quantity: 3, description: 'Shirts')

      # $1000 in Hats
      i.line_items << LineItem.new(price: 5, quantity: 200, description: 'Hats')

      expect(i.total).to eq(BigDecimal('1243'))
    end

    it "is overdue when it's past date and unpaid" do
      i = described_class.new(due_at: Date.today - 1)
      expect(i.overdue?).to be(true)
    end

    it "isn't overdue when past due date and paid" do
      i = described_class.new(due_at: Date.today - 1, paid_at: Date.today)
      expect(i.overdue?).not_to be(true)
    end

    it 'is overdue when due date is a time before the current date' do
      i = described_class.new(due_at: Time.parse('Jan 1 14:33:20 GMT 2011'))
      expect(i.overdue?).to be(true)
    end

    it 'is not refunded when not marked refunded' do
      i = described_class.new
      expect(i.refunded?).not_to be(true)
    end

    it 'is refunded when marked as refunded' do
      i = described_class.new(refunded_at: Date.today)
      expect(i.refunded?).to be(true)
    end

    it 'is not paid when not marked paid' do
      i = described_class.new
      expect(i.paid?).not_to be(true)
    end

    it 'is paid when marked as paid' do
      i = described_class.new(paid_at: Date.today)
      expect(i.paid?).to be(true)
    end

    # rubocop:todo RSpec/MultipleExpectations
    it 'is able to iterate over details' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      i = described_class.new(invoice_details: [%w[Test Yes], %w[Awesome Absolutely]])
      details = []
      i.each_detail do |key, value|
        details << [key, value]
      end

      expect(details.length).to eq(2)
      expect(details).to include(%w[Test Yes])
      expect(details).to include(%w[Awesome Absolutely])
    end

    # rubocop:todo RSpec/MultipleExpectations
    it 'is able to iterate through invoice_details as a hash' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      i = described_class.new(invoice_details:
        {'Test' => 'Yes', 'Awesome' => 'Absolutely'})
      details = []
      i.each_detail do |key, value|
        details << [key, value]
      end

      expect(details.length).to eq(2)
      expect(details).to include(%w[Test Yes])
      expect(details).to include(%w[Awesome Absolutely])
    end

    describe 'rendering' do
      before do
        FileUtils.mkdir_p('tmp')
        Config.default.reset
      end

      let(:invoice) { new_invoice(invoice_params) }
      let(:invoice_params) { {} }

      it 'renders to a file' do
        FileUtils.rm_rf('tmp/testing.pdf')

        invoice.render_pdf_to_file('tmp/testing.pdf')

        expect(File.exist?('tmp/testing.pdf')).to be true
      end

      context 'with some invoice details' do
        let(:invoice_params) do
          {
            invoice_details: {
              'Ordered By:' => 'Alan Johnson',
              'Paid By:' => 'Dude McDude'
            }
          }
        end

        it 'renders an invoice correctly' do # rubocop:todo RSpec/ExampleLength
          Payday::Config.default.company_details = <<-DETAILS
            10 This Way
            Manhattan, NY 10001
            800-111-2222
            awesome@awesomecorp.com
          DETAILS

          invoice.line_items += [
            LineItem.new(price: 20, quantity: 5, description: 'Pants'),
            LineItem.new(price: 10, quantity: 3, description: 'Shirts'),
            LineItem.new(price: 5, quantity: 200, description: 'Hats')
          ] * 30

          expect(invoice.render_pdf).to match_binary_asset 'testing.pdf'
        end
      end

      context 'with the locale set to Spanish' do
        it 'renders and invoice in Spanish' do # rubocop:todo RSpec/ExampleLength
          I18n.with_locale :es do
            Payday::Config.default.company_details = 'Dirección'

            invoice.line_items += [
              LineItem.new(price: 20, quantity: 5, description: 'Pantalones'),
              LineItem.new(price: 5, quantity: 200, description: 'Sombreros')
            ]

            expect(invoice.render_pdf).to match_binary_asset 'testing_es.pdf'
          end
        end
      end

      context 'with a mix of LineItems with price, quantity and predefined_amounts' do
        let(:invoice_params) do
          {
            invoice_details: {
              'Ordered By:' => 'Alan Johnson',
              'Paid By:' => 'Dude McDude'
            }
          }
        end

        it 'renders an invoice correctly' do # rubocop:todo RSpec/ExampleLength
          Payday::Config.default.company_details = <<-DETAILS
            10 This Way
            Manhattan, NY 10001
            800-111-2222
            awesome@awesomecorp.com
          DETAILS

          invoice.add_line_item(price: 10, quantity: 3, description: 'Extra Users')
          invoice.add_line_item(predefined_amount: 79,
                                description: "Flat Fee\n<color rgb='888888'>From date to date</color>")

          expect(invoice.render_pdf).to match_binary_asset 'testing_predefined_amount.pdf'
        end
      end

      context 'paid, with an svg logo' do # rubocop:todo RSpec/ContextWording
        before do
          logo = {filename: 'spec/assets/tiger.svg', size: '100x100'}
          Payday::Config.default.invoice_logo = logo
        end

        let(:invoice_params) { {paid_at: Date.civil(2012, 2, 22)} }

        it 'renders an invoice correctly' do # rubocop:todo RSpec/ExampleLength
          invoice.line_items += [
            LineItem.new(price: 20, quantity: 5, description: 'Pants'),
            LineItem.new(price: 10, quantity: 3, description: 'Shirts'),
            LineItem.new(price: 5, quantity: 200.0, description: 'Hats')
          ] * 3

          expect(invoice.render_pdf).to match_binary_asset 'svg.pdf'
        end
      end

      def new_invoice(params = {})
        default_params = {
          tax_rate: 0.1,
          notes: 'These are some crazy awesome notes <color rgb=\'888888\'>with color</color>!',
          invoice_number: 12,
          invoice_date: Date.civil(2011, 1, 1),
          due_at: Date.civil(2011, 1, 22),
          bill_to: "Alan Johnson\n101 This Way\nSomewhere, SC 22222",
          ship_to: "Frank Johnson\n101 That Way\nOther, SC 22229"
        }

        Invoice.new(default_params.merge(params))
      end
    end
  end

end
