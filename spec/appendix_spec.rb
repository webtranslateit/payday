# frozen_string_literal: true

require 'spec_helper'

module Payday

  describe Appendix do
    before { Config.default.reset }

    after { Config.default.reset }

    let(:invoice) do
      Invoice.new(invoice_number: 12, invoice_date: Date.civil(2011, 1, 1),
                  bill_to: "Alan Johnson\n101 This Way\nSomewhere, SC 22222").tap do |i|
        i.line_items << LineItem.new(price: 20, quantity: 5, description: 'Pants')
      end
    end

    # Counts page objects rather than reading the PDF, which keeps the suite free of a
    # reader dependency.
    def page_count(pdf)
      pdf.scan(%r{/Type\s*/Page[^s]}).size
    end

    describe '.wrap' do
      it 'passes nil through' do
        expect(described_class.wrap(nil)).to be_nil
      end

      it 'passes an appendix through' do
        appendix = described_class.new(source: '')

        expect(described_class.wrap(appendix)).to be(appendix)
      end

      it 'builds one from a hash' do
        expect(described_class.wrap({source: '#pagebreak()'}).source).to eq('#pagebreak()')
      end
    end

    it 'defaults inputs and dependencies to empty' do
      appendix = described_class.new(source: '')

      expect(appendix).to have_attributes(inputs: {}, dependencies: {})
    end

    # Typst names both by string, so a caller writing them as symbols would otherwise get
    # files and inputs the template cannot find.
    it 'stringifies input and dependency names' do
      appendix = described_class.new(source: '', inputs: {a: '1'}, dependencies: {b: 'x'})

      expect(appendix).to have_attributes(inputs: {'a' => '1'}, dependencies: {'b' => 'x'})
    end

    describe 'rendering' do
      it 'adds the appended pages to the invoice' do
        without = page_count(invoice.render_pdf)

        with = page_count(invoice.render_pdf(appendix: {source: '#pagebreak()\n= Appendix'}))

        expect(with).to eq(without + 1)
      end

      # The whole point of compiling the appendix into the invoice rather than merging a
      # second document into it. The template's footer asks Typst for the final page count and
      # numbers the pages only once there is more than one, so a one-page invoice that gains
      # an appendix has to come out numbered "1 / 2" and "2 / 2". Nothing short of the
      # rendered page shows that, hence the golden file.
      it 'numbers the invoice across the appendix' do
        appendix = described_class.new(
          source: "#pagebreak()\n#text(size: 16pt, weight: \"bold\")[Charged shipments]"
        )

        expect(invoice.render_pdf(appendix: appendix)).to match_binary_asset 'appendix.pdf'
      end

      it 'reads appendix inputs from sys.inputs' do
        appendix = described_class.new(
          source: "#pagebreak()\n#json(bytes(sys.inputs.extra)).title",
          inputs: {'extra' => {title: 'Charged shipments'}.to_json}
        )

        expect { invoice.render_pdf(appendix: appendix) }.not_to raise_error
      end

      it 'resolves appendix dependencies by name' do
        appendix = described_class.new(
          source: "#pagebreak()\n#image(\"extra.svg\", width: 50pt)",
          dependencies: {'extra.svg' => File.binread('spec/assets/tiger.svg')}
        )

        expect { invoice.render_pdf(appendix: appendix) }.not_to raise_error
      end

      it 'renders the invoice untouched when there is no appendix' do
        expect(invoice.render_pdf).to eq(PdfRenderer.render(invoice, appendix: nil))
      end

      it 'renders to a file' do
        FileUtils.mkdir_p('tmp')
        FileUtils.rm_rf('tmp/appendix.pdf')

        invoice.render_pdf_to_file('tmp/appendix.pdf', appendix: {source: '#pagebreak()\n= Appendix'})

        expect(page_count(File.binread('tmp/appendix.pdf'))).to eq(2)
      end
    end

    # An appendix that reused one of these names would replace the invoice's own data or one
    # of its files, and the invoice would render wrong rather than fail.
    describe 'reserved names' do
      it 'refuses an appendix that reuses the invoice sys_input' do
        appendix = described_class.new(source: '', inputs: {'invoice' => '{}'})

        expect { invoice.render_pdf(appendix: appendix) }
          .to raise_error(ArgumentError, /sys_input "invoice" is reserved/)
      end

      it 'refuses an appendix that reuses the logo dependency' do
        appendix = described_class.new(source: '', dependencies: {'logo.png' => 'x'})

        expect { invoice.render_pdf(appendix: appendix) }
          .to raise_error(ArgumentError, /dependency "logo.png" is reserved/)
      end

      it 'refuses an appendix that reuses the QR code dependency' do
        invoice.qr_code = 'https://example.com'
        appendix = described_class.new(source: '', dependencies: {'qr.svg' => 'x'})

        expect { invoice.render_pdf(appendix: appendix) }
          .to raise_error(ArgumentError, /dependency "qr.svg" is reserved/)
      end

      it 'allows a name the invoice did not take' do
        Config.default.invoice_logo = nil
        appendix = described_class.new(source: '', dependencies: {'logo.png' => 'x'})

        expect { invoice.render_pdf(appendix: appendix) }.not_to raise_error
      end
    end
  end

end
