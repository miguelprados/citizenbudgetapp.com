class window.SimulatorHelper
  # http://www.musicdsp.org/showone.php?id=238
  @tanh: (x) ->
    if x < -3
      -1
    else if x > 3
      1
    else
      x * (27 + x * x) / (27 + 9 * x * x)

  # @see https://github.com/rails/rails/blob/006de2577a978cd212f07df478b03053b1309c84/actionpack/lib/action_view/helpers/number_helper.rb#L208
  @number_with_delimiter: (number) ->
    parts = number.toString().split('.')
    parts[0] = parts[0].replace(/(\d)(?=(\d\d\d)+(?!\d))/g, '$1' + t('currency_delimiter'))
    parts.join(t('currency_separator'))

  # @see https://github.com/rails/rails/blob/006de2577a978cd212f07df478b03053b1309c84/actionpack/lib/action_view/helpers/number_helper.rb#L254
  # @note Doesn't implement :significant option.
  @number_with_precision: (number, options = {}) ->
    options.precision ?= 2
    # toFixed has unpredictable rounding, but small rounding errors are not an issue.
    formatted_number = @number_with_delimiter(parseFloat(number).toFixed(options.precision))
    if options.strip_insignificant_zeros
      escaped_separator = t('currency_separator').replace(///(
        [
          .     # Dot
          ?*+{} # Quantification
          [\]   # Character set
          ()    # Grouping
          ^$    # Anchors
          |     # Alternation
          \\    # Escape character
          \#    # Comment
          -     # Hyphen
        ]
      )///g, '\\$1')
      formatted_number.replace(///(#{escaped_separator})([0-9]*[1-9])?0+$///, '$1$2').replace(///#{escaped_separator}$///, '')
    else
      formatted_number

  # Converts a number to a currency.
  @number_to_currency: (number, options = {}) ->
    t 'currency_format',
      number: @number_with_precision(number, options)
      unit: t('currency_unit')

  # Converts a number to a percentage.
  @number_to_percentage: (number, options = {}) ->
    t 'percentage_format',
      number: @number_with_precision(number, options)
      symbol: t('percentage_symbol')

  # Abbreviates a number.
  # @todo use JavaScript I18n method.
  @number_to_human: (number, options = {}) ->
    number = parseFloat(number)
    options.strip_insignificant_zeros ?= true
    if Math.abs(number) >= 1000000
      "#{@number_with_precision(number / 1000000, precision: 1, strip_insignificant_zeros: true)} M"
    else if Math.abs(number) >= 1000
      "#{@number_with_precision(number / 1000, precision: 1, strip_insignificant_zeros: true)} k"
    else
      @number_with_precision(number, options)
