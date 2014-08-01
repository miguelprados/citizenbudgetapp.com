class window.Simulator
  constructor: (@options = {}, @identifier = 'simulator') ->
    # The tables belonging to this simulator.
    @scope = $("table.#{@identifier}")
    # The bar's maximum left position.
    @bar_left = 100
    # Whether the message has pulsated a first time.
    @pulsated = false
    # Administrators can override the instructions.
    @instructions = $('#message').text()

    # Add messages to I18n.
    for object in [@strings(), @messages()]
      for locale, messages of object
        for key, value of messages
          I18n[locale][key] = value
    @colors = @colorSetting()

    @initializeRadioWidgets()
    @initializeOnOffWidgets()
    @initializeSliderWidgets()
    @initializeStaticWidgets()

    if @options.disabled
      @loadAnswers()
    else
      if @options.starting_balance
        @animateBar(@net_balance())
      @prepareForm()

  # @return [Float] the factor by which to scale the budget balance
  scale: ->
    1

  # @return [Boolean] whether the respondent can submit the form
  canSubmit: ->
    not @options.change_required or @isChanged()

  # @return [Boolean] whether the form has been changed
  isChanged: ->
    !!@scope.find('.selected').length

  # @return [Float] the global or section balance
  balance: ($table) ->
    balance = 0
    $table.find('.slider').each ->
      $this = $(this)
      balance += ($this.slider('value') - parseFloat($this.data('initial'))) * parseFloat($this.data('value'))
    $table.find('.onoff').each ->
      $this = $(this)
      balance += (+$this.prop('checked') - parseFloat($this.data('initial'))) * parseFloat($this.data('value'))
    $table.find('.option').each ->
      $this = $(this)
      balance += +$this.prop('checked') * ($this.val() - parseFloat($this.data('initial')))
    balance * @scale()

  # @return [Float] the simulator's net balance
  # XXX This should be camel case to be consistent.
  net_balance: ->
    @options.starting_balance + @balance(@scope)

  enableForm: ->
    $('#identification').css('opacity', 1)
    $('#identification input,#identification textarea').prop('disabled', false)

  disableForm: ->
    $('#identification').css('opacity', 0.5)
    $('#identification input,#identification textarea').prop('disabled', true)

  # Colors and messages

  # The simulator's colors.
  colorSetting: ->
    # XXX hack to read CSS rule.
    $element = $('<tr class="selected"><td class="description"></td></tr>').appendTo('body')
    change_description_background_color = $element.find('td').css('background-color')
    $element.remove()
    $element = $('<tr class="selected"><td class="highlight"></td></tr>').appendTo('body')
    change_highlight_background_color = $element.find('td').css('background-color')
    $element.remove()

    description = $('td.description').css('background-color')
    description = 'transparent' if description is 'rgba(0, 0, 0, 0)'
    highlight = $('td.highlight').css('background-color')
    highlight = 'transparent' if highlight is 'rgba(0, 0, 0, 0)'

    # The colors of the single solid bar in the graph.
    bar:
      positive: '#000'
      negative: '#f00'
    # The colors of the status message in the navigation.
    message:
      background:
        positive: '#ff0'
        neutral: $('#message').css('background-color') # administrators can override the CSS
        negative: '#f00'
      foreground:
        positive: '#000'
        neutral: '#fff'
        negative: '#fff'
    # The colors of the budgetary values in the section navigation.
    section:
      positive: '#000'
      negative: '#f00'
    # The colors of the question and its budgetary values.
    question:
      positive: '#000'
      negative: '#d00'
      description: description # administrators can override the CSS
      highlight: highlight # administrators can override the CSS
      description_selected: change_description_background_color
      highlight_selected: change_highlight_background_color

  strings: ->
    en_US:
      gains: 'Gains:'
      losses: 'Losses:'
      savings: 'Savings:'
      costs: 'Costs:'
    fr_CA:
      gains: 'Gains :'
      losses: 'Pertes :'
      savings: 'Épargnes :'
      costs: 'Coûts :'

  messages: ->
    if @scope.find('[data-revenue]').length
      en_US:
        surplus: """Your budget has a surplus of {{number}}. If you're finished, <a href="#identification">submit your choices</a>. Otherwise, <b>add activities or cut revenues to balance the budget</b>."""
        balanced: """<b>Your budget is balanced!</b> If you're finished, <a href="#identification">submit your choices</a>."""
        deficit: 'Your budget is in deficit ({{number}}). <b>Cut activities or add revenues to balance the budget.</b>'
      fr_CA:
        surplus: """Votre budget montre un surplus de {{number}}. Vous pouvez <a href="#identification">soumettre vos choix</a>. Sinon, <b>ajoutez des activités ou reduisez les revenus pour équilibrer le budget</b>."""
        balanced: """<b>Vous avez atteint l'équilibre!</b> Si vous avez fini, <a href="#identification">soumettez vos choix</a>."""
        deficit: 'Votre budget est en déficit ({{number}}). <b>Renoncez à des activités ou augmentez les revenus pour équilibrer le budget.</b>'
    else
      en_US:
        surplus: """Your budget has a surplus of {{number}}. If you're finished, <a href="#identification">submit your choices</a>. Otherwise, <b>add activities to balance the budget</b>."""
        balanced: """<b>Your budget is balanced!</b> If you're finished, <a href="#identification">submit your choices</a>."""
        deficit: 'Your budget is in deficit ({{number}}). <b>Cut activities to balance the budget.</b>'
      fr_CA:
        surplus: """Votre budget montre un surplus de {{number}}. Vous pouvez <a href="#identification">soumettre vos choix</a>. Sinon, <b>ajoutez des activités pour équilibrer le budget</b>."""
        balanced: """<b>Vous avez atteint l'équilibre!</b> Si vous avez fini, <a href="#identification">soumettez vos choix</a>."""
        deficit: 'Votre budget est en déficit ({{number}}). <b>Renoncez à des activités pour équilibrer le budget.</b>'

  # @return [String] the CSS selector for the status message
  messageSelector: ->
    '.message'

  # @return [Object] the interpolation variables for the status message
  messageOptions: (net_balance) ->
    number: SimulatorHelper.number_to_currency(net_balance, strip_insignificant_zeros: true)
    percentage: 0

  # @return [String] the text of the status message
  message: (net_balance, options) ->
    if net_balance == 0
      if @isChanged()
        t('balanced')
      else
        @instructions
    else
      if net_balance < 0
        t('deficit', options)
      else
        t('surplus', options)

  # Sets the text of the status message.
  setMessage: (net_balance) ->
    $(@messageSelector()).html(@message(net_balance, @messageOptions(net_balance)))

  # Updates

  # Updates a question after it's been changed.
  updateQuestion: ($control, current) ->
    $tr     = $control.parents('tr')
    current = parseFloat(current)
    initial = parseFloat($control.data('initial'))
    value   = parseFloat($control.data('value'))
    revenue = $control.data('revenue')

    if current == initial
      $tr.find('.key').html('')
      $tr.find('.value').html(SimulatorHelper.number_to_currency(0, strip_insignificant_zeros: true))
      $tr.find('.impact').css('visibility', 'hidden')

      if $tr.hasClass('selected')
        $tr.removeClass('selected')
        $tr.find('td.description').animate('background-color': @colors.question.description, 'slow')
        $tr.find('td.highlight').animate('background-color': @colors.question.highlight, 'slow')
    else
      difference = (current - initial) * value
      if difference >= 0
        key = if revenue then t('gains') else t('savings')
        color = @colors.question.positive
      else
        key = if revenue then t('losses') else t('costs')
        color = @colors.question.negative

      $tr.find('.key').html(key)
      $tr.find('.value').html(SimulatorHelper.number_to_currency(Math.abs(difference) * @scale($tr), strip_insignificant_zeros: true))
      $tr.find('.impact').css('color', color).css('visibility', 'visible')

      unless $tr.hasClass('selected')
        $tr.addClass('selected')
        $tr.find('td.description').animate('background-color': @colors.question.description_selected, 'fast')
        $tr.find('td.highlight').animate('background-color': @colors.question.highlight_selected, 'fast')

  # Updates a section after a change has been made to the budget.
  updateSection: ($control) ->
    $table = $control.parents('table')

    $anchor = if $table.find('th.category').text().replace(/^\s+|\s+$/g, '') or $table.prev('table').find('tbody tr').length
      $table
    else
      $table.prev('table')

    $span = $('#' + $anchor.attr('id') + '_link span')
    if $span.parents('.dropdown-menu').length
      balance = @balance($table)
      $span.html(SimulatorHelper.number_to_currency(balance, strip_insignificant_zeros: true)).css('color', if balance >= 0 then @colors.section.positive else @colors.section.negative).toggle(balance != 0)

  # Updates the simulator after a change has been made to the budget.
  update: ->
    net_balance = @net_balance()

    @animateBar(net_balance)
    @setMessage(net_balance)
    @animateMessage(net_balance)

    # Enable or disable the identification form.
    if @canSubmit()
      @enableForm()
    else
      @disableForm()

  # Animation

  animateBar: (net_balance) ->
    self = this

    # Update graph and move bar and balance.
    $amount = $("##{@identifier} .amount")
    $bar = $("##{@identifier} .bar")

    if $bar.length
      amount = SimulatorHelper.number_to_currency(net_balance, strip_insignificant_zeros: true)
      $amount.html(amount).toggleClass('negative', net_balance < 0)

      # If pixels are less than zero, the bar moves right (increase).
      pixels = -Math.round(SimulatorHelper.tanh(3 * net_balance / @options.maximum_difference / @scale()) * 100)
      width = Math.abs(pixels)

      # If at zero.
      if $bar.width() == 0
        $amount.animate(left: -pixels)
        $bar.css('background-color', if pixels < 0 then @colors.bar.positive else @colors.bar.negative).animate
          left: Math.min(@bar_left, @bar_left - pixels)
          width: width
      # If going from negative to positive.
      else if pixels < 0 and $bar.position().left < @bar_left
        $amount.animate(left: 0).animate(left: -pixels)
        $bar.animate
          left: @bar_left,
          width: 0
        ,
          complete: ->
            $(this).css('background-color', self.colors.bar.positive)
        .animate
          width: width
      # If going from positive to negative.
      else if pixels > 0 and $bar.position().left == @bar_left
        $amount.animate(left: 0).animate(left: -pixels)
        $bar.animate
          width: 0
        ,
          complete: ->
            $(this).css('background-color', self.colors.bar.negative)
        .animate
          left: @bar_left - pixels
          width: width
      # If not crossing zero.
      else
        $amount.animate(left: -pixels)
        $bar.css('background-color', if pixels < 0 then @colors.bar.positive else @colors.bar.negative).animate
          left: Math.min(@bar_left, @bar_left - pixels)
          width: width

  # Pulsates and changes the colors of the status message.
  animateMessage: (net_balance) ->
    changed = @isChanged()
    $message = $(@messageSelector())

    key = if net_balance >= 0 and changed
      'positive'
    else if net_balance < 0
      'negative'
    else # balance is zero and budget is unchanged
      'neutral'

    $message.animate
      'background-color': @colors.message.background[key]
      'color': @colors.message.foreground[key]

    if changed and not @pulsated
      @pulsated = true
      $message.effect('pulsate', times: 1)

  # Widgets

  # Budgetary radio buttons.
  initializeRadioWidgets: ->
    self = this

    @scope.find('.option').change ->
      self.track()
      $this = $(this)
      self.updateQuestion($this, $this.val())
      self.updateSection($this)
      self.update()

  # On/off widgets.
  initializeOnOffWidgets: ->
    self = this

    @scope.find('.onoff').each ->
      options =
        resizeContainer: false
        resizeHandle: false
        onChange: (input, checked) ->
          self.track()
          self.updateQuestion(input, +checked)
          self.updateSection(input)
          self.update()

      $this = $(this)

      if parseFloat($this.data('initial')) == 1
        options.checkedLabel = $this.data('no-label')
        options.uncheckedLabel = $this.data('yes-label')
        options.labelOffClass = 'iPhoneCheckLabelOff reverse'
        options.labelOnClass = 'iPhoneCheckLabelOn reverse'
      else
        options.checkedLabel = $this.data('yes-label')
        options.uncheckedLabel = $this.data('no-label')

      $this.iphoneStyle(options)

  # Slider widgets.
  initializeSliderWidgets: ->
    self = this

    # Must be global for `loadAnwers` call.
    window.updateTip = ($slider, value) ->
      content = self.tipSlider($slider, value)
      $slider.find('.tip-content').html(content) if content
      $slider.find('.tip').toggle(value != parseFloat($slider.data('minimum')))

    # `change` will be called once the respondent stops sliding.
    slide = (event, ui) ->
      $this = $(this)
      value = ui.value
      updateTip($this, value)
      self.updateQuestion($this, value)

    change = (event, ui) ->
      self.track()
      $this = $(this)
      slide.call(this, event, ui)
      $this.find('input').val(ui.value) # update the associated form element
      self.updateSection($this)
      self.update()

    @scope.find('.slider').each ->
      $this   = $(this)
      initial = parseFloat($this.data('initial'))
      minimum = parseFloat($this.data('minimum'))
      maximum = parseFloat($this.data('maximum'))
      actual  = parseFloat($this.data('actual'))

      $this.slider
        animate: true
        max: maximum
        min: minimum
        range: 'min'
        step: parseFloat($this.data('step'))
        value: initial
        create: (event, ui) ->
          content = self.tipSlider($this, initial)
          $(this).find('a').append('<div class="tip"><div class="tip-content">' + content + '</div><div class="tip-arrow"></div></div>') if content
          $(this).find('.tip').toggle(initial != minimum)
        slide: not self.options.disabled and slide
        change: not self.options.disabled and change
        disabled: self.options.disabled

      # Place the initial tick according to the handle's default position.
      if initial != maximum and initial != minimum
        $this.find('.tick.initial').width($this.find('a').position().left + 1).show()

      # We place the initial tick according to the handle's default position, so
      # we can't set the value during slider initialization.
      unless isNaN(actual)
        $this.slider('value', actual)

    # Keyboard input can be confusing if the slider is not visible.
    @scope.find('.ui-slider-handle').unbind('keydown')

  # Static widgets.
  initializeStaticWidgets: ->
    self = this

    @scope.find('.control-static').each ->
      $this = $(this)
      content = t 'assessment_unit', number: self.tipSlider($this, 1.0), assessment_period: t(self.options.assessment_period)
      $this.html(content)

  initializeMinMaxLabels: ->
    $('.minimum').click ->
      $this = $(this)
      $widget = $this.parents('.widget')
      $widget.find('.onoff').prop('checked', false).trigger('change')
      $slider = $widget.find('.slider')
      $slider.slider('value', $slider.data('minimum')) # triggers `change`

    $('.maximum').click ->
      $this = $(this)
      $widget = $this.parents('.widget')
      $widget.find('.onoff').prop('checked', true).trigger('change')
      $slider = $widget.find('.slider')
      $slider.slider('value', $slider.data('maximum')) # triggers `change`

  # @return [String] content for the tip on a slider
  tipSlider: ($widget, number) ->
    if $widget.data('widget') in ['scaler', 'static']
      @tipScaler($widget, number)
    else if not $widget.data('yes-no')
      SimulatorHelper.number_to_human(number)

  # @return [String] content for the tip on a scaler
  tipScaler: ($widget, number) ->
    SimulatorHelper.number_to_percentage(number * 100, strip_insignificant_zeros: true)

  loadAnswers: ->
    self = this

    @update()

    @scope.find('input:first').each ->
      self.updateSection($(this))

    @scope.find('.option:checked').each ->
      $this = $(this)
      self.updateQuestion($this, $this.val())

    @scope.find('.onoff').each ->
      $this = $(this)
      self.updateQuestion($this, +$this.prop('checked'))

    @scope.find('.slider').each ->
      $this = $(this)
      value = $this.slider('value')
      updateTip($this, value)
      self.updateQuestion($this, value)

  track: ->
    _gaq.push(['_trackEvent', 'Simulators', 'Modify', @options.questionnaire_id]) if _gaq?

  prepareForm: ->
    @initializeMinMaxLabels()
    $('#new_response').validationEngine()
    @disableForm() unless @canSubmit()
