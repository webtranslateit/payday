Payday!
===
Payday is a library for rendering invoices to pdfs.

We use payday intensively at [WebTranslateIt.com](https://webtranslateit.com) and [Trackberry](https://trackberry.com) to generate customer’s invoices and receipts. When we upgraded our app to ruby 2.7 this gem failed in many ways and the original source code by Alan Johnson was nowhere to be found on GitHub. So we took the source code out of [rubygems.org](https://rubygems.org) and created this repo. We’ve since added a few new features and fixes, which can be seen [in the changelog](https://github.com/webtranslateit/payday/blob/main/CHANGELOG.md).

Invoices can now carry a QR code, which a growing number of countries expect for tax compliance, and as of 2.0 the PDFs are rendered with [Typst](https://typst.app) rather than Prawn.

Here’s an [example PDF Invoice](https://github.com/webtranslateit/payday/raw/main/spec/assets/testing_predefined_amount.pdf) generated with our fork of payday.

Installing
===
Payday is available as a Rubygem, so installing it is as easy as running:

```
gem install webtranslateit-payday
```

Or, using bundler:

```
gem 'webtranslateit-payday', require: 'payday'
```

Using Payday
===
It's pretty easy to use Payday with the built in objects. We include the Invoice and LineItem classes, and with them you can get started pretty quickly.

Example:

``` ruby
invoice = Payday::Invoice.new(invoice_number: 12)
# 2 lines with a price and a quantity. Amount will be calculated by price * quantity
invoice.add_line_item(price: 20, quantity: 5, description: 'Pants')
invoice.add_line_item(price: 10, quantity: 3, description: 'Shirts')
# a line with no price or quantity but with a predefined price (or flat fee)
invoice.add_line_item(predefined_amount: 10, description: 'Shipping')
invoice.render_pdf_to_file('/path/to_file.pdf')
```

Documentation
===
Documentation for the latest version of Payday is available at [rubydoc.info](http://www.rubydoc.info/gems/payday).

Customizing Your Invoice
===
`Payday::Config` includes quite a few options for customizing your invoices, such as options for customizing the logo and
company details on the invoice.

Example:

``` ruby
Payday::Config.default.invoice_logo = "/path/to/company/logo.png"
Payday::Config.default.company_name = "Awesome Corp"
Payday::Config.default.company_details = "10 This Way\nManhattan, NY 10001\n800-111-2222\nawesome@awesomecorp.com"
```

The logo can be a PNG, a JPEG or an SVG, and is drawn at its natural size. Pass a hash to
constrain it:

``` ruby
Payday::Config.default.invoice_logo = {filename: "logo.svg", size: "200x50"}
```

`page_size` accepts `"LETTER"`, `"A4"` and `"LEGAL"`.

QR Code Support
===
Invoices can include QR codes for verification purposes, useful for tax compliance requirements in various countries.

Example:

``` ruby
invoice = Payday::Invoice.new(
  invoice_number: 12345,
  qr_code: 'https://verify.example.com/invoice/12345',
  notes: 'Scan the QR code below to verify this invoice online.'
)
```

QR codes are automatically rendered below the notes section, as vector SVG so they stay
sharp in print. The code itself comes straight from [rqrcode](https://github.com/whomwah/rqrcode),
so the payload and its error correction level are exactly what that gem produces.

Using Payday with ActiveRecord Objects (or any other objects, for that matter)
===

Payday focuses on two main objects, an invoice and a line item, so to use Payday with ActiveRecord you'll want to create your own classes for those objects. We include the Payday::Invoiceable and Payday::LineItemable modules to help out with that.

Thanks to the work of Andrew Nordman, Payday includes a Rails generator that makes it super simple to generate the necessary models and migration for wiring Payday up to your app. Run `rails generate payday:setup --help` for more information about using the generator.

For a bit more fleshed out example, be sure to check out [http://github.com/commondream/payday-example](http://github.com/commondream/payday-example).

Rendering Payday PDFs To The Web
===
Payday's Invoiceable module includes methods for rendering pdfs to disk and for rendering them to a string. In a Rails controller, you can use the
render to string method to render a pdf directly to the browser like this:

In `config/initializers/mime_types.rb`:

``` ruby
Mime::Type.register 'application/pdf', :pdf
```

In your controller:

``` ruby
respond_to do |format|
  format.html
  format.pdf do
    send_data invoice.render_pdf, filename: 'Invoice #12.pdf', type: 'application/pdf', disposition: 'inline'
  end
end
```

Be sure to restart your server after you edit the mime_types initializer. The updated setting won't take effect until you do.

Appending your own pages
===
Pass a `Payday::Appendix` to add pages of your own to the end of an invoice — a per-item breakdown, a delivery note, terms and conditions:

``` ruby
appendix = Payday::Appendix.new(
  source: File.read('appendix.typ'),
  inputs: {'shipments' => shipments.to_json},
  dependencies: {'chart.svg' => File.binread('chart.svg')}
)

invoice.render_pdf(appendix: appendix)
```

`source` is [Typst](https://typst.app) markup appended to Payday's own template, so it is compiled as part of the invoice rather than as a second PDF you would then have to merge in. Two things follow from that: your pages inherit the invoice's page setup and margins, and the page counter runs across the whole document, so the numbering footer counts your pages too. A one-page invoice with one appended page comes out numbered "1 / 2" and "2 / 2".

`inputs` reach the template as [sys_inputs](https://typst.app/docs/reference/foundations/sys/), read with `json(bytes(sys.inputs.shipments))`. `dependencies` are files the source can reach by name, with `image("chart.svg")` and the like. Reusing a name the invoice has already taken — the `invoice` input, or the logo and QR code files — raises an `ArgumentError` rather than quietly replacing it.

**Pass your data through `inputs`, never by interpolating it into `source`.** Typst treats a string arriving through `sys.inputs` as literal text, which is what stops a customer-supplied field from affecting the layout. `source` is code: interpolating invoice data into it hands anyone who can set a field on an invoice a way to write Typst.

An appendix that reads its data and prints a heading:

``` typst
#let a = json(bytes(sys.inputs.shipments))

#pagebreak()
#text(size: 16pt, weight: "bold")[#a.title]
```

I18n
===
Payday uses the i18n gem to provide support for custom labels and internationalized applications. You can change the default labels by adding a YAML file in the `config/locales` directory of your Rails app. Here are the default labels you can customize:

``` yaml
en:
  payday:
    status:
      paid: PAID
      overdue: OVERDUE
      refunded: REFUNDED
    invoice:
      bill_to: Bill To
      ship_to: Ship To
      invoice_no: "Invoice #:"
      due_date: "Due Date:"
      paid_date: "Paid Date:"
      subtotal: "Subtotal:"
      tax: "Tax:"
      total: "Total:"
    line_item:
      description: Description
      unit_price: Unit Price
      quantity: Quantity
      amount: Amount
```

If you translate the invoice to your own language, please send me a copy of your locale.yml file so that we can include it with
the main Payday distribution and other Payday users can enjoy the fruits of your labor.

Examples
===
Here's an [example PDF Invoice](https://github.com/webtranslateit/payday/raw/main/spec/assets/testing_predefined_amount.pdf)

Contributing
===
Payday is pretty young, so there's still a good bit of work to be done. I highly recommend sending me a message on GitHub before making too many changes, just to make sure that two folks aren't doing the same work, but beyond that feel free to fork the project, make some changes, and send a pull request. If you're unsure about what to work on but would like to help, send me a message on GitHub. I'd love the help!

We've had some awesome contributers:

* Sam Pizzey ([pizzeys](http://github.com/pizzeys))
* Andrew Nordman ([cadwallion](http://github.com/cadwallion))
* Pierre Olivier Martel ([pomartel](http://github.com/pomartel))
* Matt Hoofman ([mhoofman](https://github.com/mhoofman))
* Édouard Brière ([edouard](https://github.com/edouard))
* Jim Jones ([aantix](https://github.com/aantix))
* Hussein Morsy ([husseinmorsy](https://github.com/husseinmorsy))

To Do
===
Here's what we're planning on working on with Payday in the near future:

* Actually get a designer to style the invoices.
* Add support for Money values
* Add support for blank line items
* Add support for indented line items
* Apply different tax rates to different line items
* Add support for shipping either pre or post tax
* Add ability to show skus or product ids on each line item
* Add ability to add fine print to invoices.
* Ability to render invoice to html for web viewing

Acknowledgements
===
Payday renders with [Typst](https://typst.app) and its [Ruby binding](https://github.com/actsasflinn/typst-rb).

For its first decade this gem was built on [Prawn](https://prawnpdf.org), and it would not exist without that project and the team behind it.

License
===
Copyright (C) 2011 by Alan Johnson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
