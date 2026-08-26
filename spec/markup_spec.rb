# frozen_string_literal: true

require 'spec_helper'

module Payday

  describe Markup do
    describe '.to_runs' do
      it 'returns a single plain run for unmarked text' do
        expect(described_class.to_runs('Hello')).to eq([{text: 'Hello'}])
      end

      it 'returns nil for nil' do
        expect(described_class.to_runs(nil)).to be_nil
      end

      it 'marks bold segments' do
        expect(described_class.to_runs('a <b>b</b> c')).to eq(
          [{text: 'a '}, {text: 'b', bold: true}, {text: ' c'}]
        )
      end

      it 'marks italic segments' do
        expect(described_class.to_runs('<i>x</i>')).to eq([{text: 'x', italic: true}])
      end

      it 'extracts font size' do
        expect(described_class.to_runs("<font size='12'>big</font>")).to eq(
          [{text: 'big', size: 12}]
        )
      end

      it 'extracts colour' do
        expect(described_class.to_runs("<color rgb='777777'>grey</color>")).to eq(
          [{text: 'grey', color: '777777'}]
        )
      end

      it 'extracts links' do
        expect(described_class.to_runs("<link href='mailto:a@b.c'>mail</link>")).to eq(
          [{text: 'mail', link: 'mailto:a@b.c'}]
        )
      end

      it 'handles nested tags' do
        expect(described_class.to_runs("<font size='12'><b>Thanks!</b></font>")).to eq(
          [{text: 'Thanks!', bold: true, size: 12}]
        )
      end

      it 'marks underlined segments' do
        expect(described_class.to_runs('<u>x</u>')).to eq([{text: 'x', underline: true}])
      end

      it 'marks struck-through segments' do
        expect(described_class.to_runs('<strikethrough>x</strikethrough>')).to eq(
          [{text: 'x', strike: true}]
        )
      end

      it 'marks subscript and superscript segments' do
        expect(described_class.to_runs('<sub>a</sub><sup>b</sup>')).to eq(
          [{text: 'a', sub: true}, {text: 'b', sup: true}]
        )
      end

      it 'converts br tags to newlines' do
        expect(described_class.to_runs('a<br/>b')).to eq([{text: "a\nb"}])
      end

      it 'leaves Typst metacharacters untouched' do
        expect(described_class.to_runs('#strong[x] *y* $z$')).to eq(
          [{text: '#strong[x] *y* $z$'}]
        )
      end

      it 'keeps text surrounding a tag in order' do
        expect(described_class.to_runs("one <b>two</b> three <i>four</i>")).to eq(
          [{text: 'one '}, {text: 'two', bold: true}, {text: ' three '}, {text: 'four', italic: true}]
        )
      end
    end

    # These are the exact strings webtranslateit.com stores in its locale files. If any of
    # them stops converting, an invoice renders raw markup to a customer.
    describe 'webtranslateit.com locale strings' do
      it 'converts the thank you note' do
        expect(described_class.to_runs("<font size='12'><b>Thank you for your business!</b></font>")).to eq(
          [{text: 'Thank you for your business!', bold: true, size: 12}]
        )
      end

      it 'converts the billing period line' do
        expect(described_class.to_runs("\n<color rgb='777777'>From 1 Jan to 31 Dec</color>")).to eq(
          [{text: "\n"}, {text: 'From 1 Jan to 31 Dec', color: '777777'}]
        )
      end

      it 'converts the receipt note with its mailto link' do
        source = 'No payment is due. Contact us at ' \
                 "<link href='mailto:finance@webtranslateit.com'>finance@webtranslateit.com</link>."

        expect(described_class.to_runs(source)).to eq(
          [{text: 'No payment is due. Contact us at '},
           {text: 'finance@webtranslateit.com', link: 'mailto:finance@webtranslateit.com'},
           {text: '.'}]
        )
      end
    end
  end

end
