class window.TaxSimulator extends window.Simulator
  constructor: (@options = {}) ->
    super
    self = this

    # Override to not toggle tip at minimum value.
    window.updateTip = ($slider, value) ->
      if updateTipOverride?
        updateTipOverride($slider, value)
      else
        content = self.tipSlider($slider, value)
        $slider.find('.tip-content').html(content) if content

    # In order to set appropriate labels on slider widgets, we must multiply the
    # personal tax impact by a to-be-determined multipler.
    # this.scope.find('.widget-slider').each ->
    #   $widget = $(this)
    #   $slider = $widget.find('.slider')

    #   $widget.find('.minimum-amount').html(SimulatorHelper.number_to_currency(($slider.data('minimum') - $slider.data('initial')) * $slider.data('value') * multiplier))
    #   $widget.find('.maximum-amount').html(SimulatorHelper.number_to_currency(($slider.data('maximum') - $slider.data('initial')) * $slider.data('value') * multiplier))

    $('#assessment input').bind 'keydown keypress keyup', (event) ->
      if event.keyCode == 13
        event.preventDefault()
        $(this).blur()
    $('#assessment input').blur ->
      # Reset to default value if custom value is invalid.
      $('#assessment input').val('') if self.customAssessment() <= 0

      self.scope.find('input:first').each ->
        self.updateSection($(this))

      # Not all widgets have been implemented in "Taxes" mode.
      self.scope.find('.widget-scaler').each ->
        $widget = $(this)
        $slider = $widget.find('.slider')

        # @see Simulator#updateQuestion
        difference = ($slider.slider('value') - $slider.data('initial')) * $slider.data('value')
        $widget.find('.value').html(SimulatorHelper.number_to_currency(Math.abs(difference) * self.scale(), strip_insignificant_zeros: true))

        # In case we display minimum and maximum values again:
        # $widget.find('.minimum.taxes').html(SimulatorHelper.number_to_currency(taxAmount($slider, $slider.data('minimum'))))
        # $widget.find('.maximum.taxes').html(SimulatorHelper.number_to_currency(taxAmount($slider, $slider.data('maximum'))))

        updateTip($slider, $slider.slider('value'))

      self.scope.find('.control-static').each ->
        $widget = $(this)
        content = t 'assessment_unit', number: self.tipSlider($widget, 1.0), assessment_period: t(self.options.assessment_period)
        $widget.html(content)

      # Need to update all numbers to match the new assessment.
      self.update()

  colorSetting: ->
    setting = super
    setting.message.background.positive = '#000'
    setting.message.background.negative = '#000'
    setting.message.foreground.positive = '#fff'
    setting.question.negative = '#000'
    setting

  strings: ->
    en_US:
      gains: 'Increase:'
      losses: 'Decrease:'
      savings: 'Decrease:'
      costs: 'Increase:'
    fr_CA:
      gains: 'Augmentation :'
      losses: 'Diminution :'
      savings: 'Diminution :'
      costs: 'Augmentation :'
    fr_FR:
      gains: 'Augmentation :'
      losses: 'Diminution :'
      savings: 'Diminution :'
      costs: 'Augmentation :'
    uk_UA:
      gains: 'Зільшити:'
      losses: 'Зменшити:'
      savings: 'Зменшити:'
      costs: 'Збільшити:'

  messages: ->
    en_US:
      surplus: 'You have decreased your tax dollars by {{number}}/{{assessment_period}} or {{percentage}}. This could result in a service level reduction.'
      balanced: 'Your budget is balanced.'
      deficit: 'You have increased your tax dollars by {{number}}/{{assessment_period}} or {{percentage}}. This could result in a service level enhancement.'
    fr_CA:
      surplus: 'Vos impôts diminueraient de {{number}}/{{assessment_period}}, donc {{percentage}}. Il peut en résulter une réduction du niveau de service.'
      balanced: "Vous avez atteint l'équilibre."
      deficit: 'Vos impôts augmenteraient de {{number}}/{{assessment_period}}, donc {{percentage}}. Cette augmentation peut se traduire par un niveau de service amélioré.'
    fr_FR:
      surplus: 'Vos impôts diminueraient de {{number}}/{{assessment_period}}, donc {{percentage}}. Il peut en résulter une réduction du niveau de service.'
      balanced: "Vous avez atteint l'équilibre."
      deficit: 'Vos impôts augmenteraient de {{number}}/{{assessment_period}}, donc {{percentage}}. Cette augmentation peut se traduire par un niveau de service amélioré.'
    uk_UA:
      surplus: 'Ви зменшили об'єм податків на {{number}}/{{assessment_period}} або {{percentage}}. Це може призвести до погіршення якості послуг.'
      balanced: 'Ваш бюджет збалансовано.'
      deficit: 'Ви збільшили об'єм податків на {{number}}/{{assessment_period}} або {{percentage}}. Це може призвести до покращення якості послуг.'


  messageOptions: (net_balance) ->
    number: SimulatorHelper.number_to_currency(Math.abs(net_balance), strip_insignificant_zeros: true)
    percentage: SimulatorHelper.number_to_percentage(Math.abs(net_balance) / @options.tax_rate / @scale() * 100, strip_insignificant_zeros: true)
    assessment_period: t(@options.assessment_period)

  setMessage: (net_balance) ->
    super
    $('#reminder').toggleClass('hide', not @isChanged())

  scale: ->
    denominator = if @options.assessment_period is 'year' then 1.0 else 12.0
    (@customAssessment() || @options.default_assessment) / denominator

  # @return [Integer] the participant's custom property assessment
  # @todo Non-English participants may enter a comma as the decimal mark.
  customAssessment: ->
    parseFloat($('#assessment input').val().replace(/[^0-9.-]/g, '')) if $('#assessment input').length

  # @return [Float] the impact of a single change to the budget
  taxAmount: ($widget, number) ->
    parseFloat($widget.data('value')) * parseFloat(number) * @scale()

  # @return [String] content for the tip on a scaler
  tipScaler: ($widget, number) ->
    options = {}
    options.strip_insignificant_zeros = true
    options.precision = 0 if @options.assessment_period is 'year'
    SimulatorHelper.number_to_currency(Math.abs(@taxAmount($widget, number)), options)
