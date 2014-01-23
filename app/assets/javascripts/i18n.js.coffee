window.I18n =
  en_US:
    currency_delimiter: ','
    currency_format: '{{unit}}{{number}}'
    currency_separator: '.'
    currency_unit: '$'
    percentage_format: '{{number}}{{symbol}}'
    percentage_symbol: '%'
    assessment_unit: '{{number}}/{{assessment_period}}'
    instructions: 'Change an activity to start'
    copy_hint: 'copy to clipboard'
    copied_hint: 'copied!'
    month: 'month'
    year: 'year'
  fr_CA:
    currency_delimiter: ' '
    currency_format: '{{number}} {{unit}}'
    currency_separator: ','
    currency_unit: '$'
    percentage_format: '{{number}} {{symbol}}'
    percentage_symbol: '%'
    assessment_unit: '{{number}}/{{assessment_period}}'
    instructions: 'Modifiez une activité pour commencer'
    copy_hint: 'copier dans le presse papier'
    copied_hint: 'copié!'
    month: 'mois'
    year: 'année'

window.t = (string, args = {}, dict = I18n) ->
  current_locale = args.locale or window.locale or 'en'
  string = dict[current_locale][string] or string
  string = Mustache.render string, args
  string
