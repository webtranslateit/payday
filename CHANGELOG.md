# CHANGELOG

## 1.2.3 (2022-02-02)

* Fix deprecation warning.

## 1.2.2 (2022-02-02)

* Dependency updates (prawn, prawn-svg, add prawn-table). This update might break tests as PDF are rendered slightly differently.
* Fix deprecation warning.

## 1.2.1 (2022-02-01)

* Add convenience method to add line_items to invoices (`Invoice#add_line_item(options)`). Takes the same options as `LineItem.new(options)`.

## 1.2.0 (2021-12-22)

This brings changes made for WebTranslateIt.com’s billing system:

* Tax rate is a full percent number (for instance `21.0` for a 21% tax rate, `10.0` for a 10% tax rate). This is a breaking change compared to the previous `0.21` for 21% tax rate and `0.1` for 10% tax rate, but it is more convenient to use.
* Invoices were updated to call the document `Invoice` if the document was not paid or `Receipt` if the document was paid.

## 1.1.7 (2021-12-22)

* Remove `.ruby-version` file locking ruby at 2.1.5.
* Add CI.
* Ruby 2.6, 2.7 and 3.0 compatibility.
* Specify dependencies to `activesupport` and `rexml` in gemspec.
* Fix deprecation warnings with newer versions of the Money gem.

## 1.1.6 (2021-11-29)

* Ruby 2.6 Compatibility.

## 1.1.4 (2015-05-29)

* Bumped money gem to 6.5 (was 6.1.1)
* Bumped i18n gem to 0.7 (was 0.6.11)
* Added German translation for invoice date.

## 1.1.3 (2015-01-02)

* Loosened requirements on Money gem.
* Bumped rspec to latest and cleared up a deprecation warning.
* Added support for `invoice_date` field (thanks [danielma](https://github.com/danielma)!)
* Bugfix: Resolved issue where money values were being shown at 1/100th of the intended amount (thanks [watsonbox](https://github.com/watsonbox)!)

## 1.1.2 (2014-05-03)

* Added NL locale (thanks [jedi4ever](https://github.com/jedi4ever)!).
* Updated Prawn to 1.0.
* Updated Prawn SVG to 0.15.0.0.
* Updated Money to 6.1.1.
* Updated i18n to 0.6.9.

## 1.1.1 (2013-07-20)

* Added support for zh-CN locale (thanks [Martin91](https://github.com/Martin91)!).
